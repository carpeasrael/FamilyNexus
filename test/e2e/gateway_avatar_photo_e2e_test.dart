import 'dart:convert';
import 'dart:typed_data';

import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_avatar_photo_store.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/sync/avatar_photo_sync.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_service.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/avatar_photo_fixtures.dart';
import 'e2e_support.dart';

/// #434, E-111: Avatar-Fotos als verschlüsselte Ereignisse gegen den echten Synapse, über die ganze Kette
/// (Gateway, Signal-Scan, Sync, lokale Ablage). Läuft nur mit `tool/e2e.sh` (Docker, Synapse, vodozemac).
///
/// Der Schalter `AvatarPhotoFlags.enabled` ist in diesem Stand `false`; die Tests schalten die Sync-Klasse
/// ausdrücklich über den Konstruktor ein.

/// Wie in der App: Anmeldung, dann Pflicht-Schlüsselsicherung (nur verifizierte Geräte erhalten Schlüssel).
Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix, ensureAvatarPermission: false);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

/// Beitritt über Anfrage → Bestätigung → Annahme (dupliziert aus `gateway_avatar_e2e_test.dart`, dort dateiprivat).
Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => user.joinRequestPending, what: 'Anfrage wartet');
  await E2e.until(
    () => mod.family?.member(user.userId!)?.status == MemberStatus.requested,
    what: 'Moderator sieht Anfrage',
  );
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

/// Ein Gerät mit lokaler Ablage, Dienst und eingeschaltetem Sync.
class _Peer {
  _Peer(this.gateway, this.db, this.store, this.service, this.sync);
  final SdkMatrixGateway gateway;
  final Database db;
  final SqlAvatarPhotoStore store;
  final AvatarPhotoService service;
  final AvatarPhotoSync sync;

  String get userId => gateway.userId!;
  String get roomId => service.roomId;

  static Future<_Peer> start(SdkMatrixGateway g) async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    final store = SqlAvatarPhotoStore(db);
    final service = AvatarPhotoService(
      store: store,
      roomId: g.family!.roomId,
      myUserId: g.userId!,
      isModerator: (id) => Permissions.isModeratorId(g.family, id),
      isMember: (id) => g.family?.member(id)?.status == MemberStatus.joined,
    );
    final sync = AvatarPhotoSync(
      gateway: g,
      service: service,
      store: store,
      enabled: true,
      retryInterval: const Duration(seconds: 2),
    );
    sync.start();
    return _Peer(g, db, store, service, sync);
  }

  Future<void> close() async {
    sync.dispose();
    await db.close();
  }
}

/// Das größte erlaubte Foto: 192 × 192 mit Rauschen, die höchste Qualität, die noch unter 16 KiB bleibt.
Uint8List _largestLegalPhoto() {
  for (var q = 90; q >= 10; q -= 5) {
    final b = jpegBytes(width: 192, height: 192, quality: q, noisy: true);
    if (b.length <= AvatarPhotoLimits.maxBytes) return b;
  }
  throw StateError('kein Testfoto unter 16 KiB');
}

void main() {
  group('Avatar-Fotos als verschlüsselte Ereignisse (#434, E-111)', skip: E2e.enabled ? false : E2e.skipReason, () {
    final peers = <_Peer>[];
    tearDown(() async {
      for (final p in peers) {
        await p.close();
      }
      peers.clear();
    });

    Future<({SdkMatrixGateway g1, SdkMatrixGateway g2, _Peer p1, _Peer p2})> twoMembers(String prefix) async {
      final g1 = await _login('${prefix}1');
      await g1.createFamily('Foto-Familie');
      await E2e.until(() => g1.family != null, what: 'Familie angelegt');
      final g2 = await _login('${prefix}2');
      await _join(g1, g2);
      final p1 = await _Peer.start(g1);
      final p2 = await _Peer.start(g2);
      peers.addAll(<_Peer>[p1, p2]);
      return (g1: g1, g2: g2, p1: p1, p2: p2);
    }

    test(
      '(a) Foto, Ändern, Entfernen; Ereignisgröße unter dem Limit; die frühere eigene Kopie wird geschwärzt',
      () async {
        final t = await twoMembers('ph-a');
        final big = _largestLegalPhoto();
        final first = await t.p2.service.setOwn(big);
        await t.p2.sync.publishPending();
        await E2e.untilAsync(
          () async => (await t.p1.service.visible(t.g2.userId!))?.id == first.id,
          what: 'G1 sieht das Foto von G2',
        );
        expect((await t.p1.service.visible(t.g2.userId!))!.bytes, first.bytes);

        // Größe des tatsächlich gesendeten, verschlüsselten Ereignisses (nicht des Klartexts).
        final firstEvent = (await t.p2.store.photo(t.p2.roomId, t.g2.userId!))!.eventId;
        expect(firstEvent, isNotEmpty);
        final room = t.g1.sdkClient!.getRoomById(t.g1.family!.roomId)!;
        final raw = (await room.getEventById(firstEvent))!.originalSource!.toJson();
        final size = utf8.encode(json.encode(raw)).length;
        expect(size, lessThan(65536), reason: 'Limit des Servers');
        expect(size, greaterThan(15000), reason: 'es ist wirklich ein großes Ereignis');

        // Ändern: das neuere Foto gilt, die erste Kopie wird geschwärzt.
        final second = await t.p2.service.setOwn(jpegBytes(width: 120, height: 120));
        await t.p2.sync.publishPending();
        await E2e.untilAsync(
          () async => (await t.p1.service.visible(t.g2.userId!))?.id == second.id,
          what: 'G1 sieht das neue Foto',
        );
        await E2e.untilAsync(
          () async => (await room.getEventById(firstEvent))?.redacted ?? false,
          what: 'erste Kopie geschwärzt',
        );

        // Entfernen
        await t.p2.service.clearOwn();
        await t.p2.sync.publishPending();
        await E2e.untilAsync(
          () async => await t.p1.service.visible(t.g2.userId!) == null,
          what: 'G1 sieht kein Foto mehr',
        );
      },
    );

    test('(b) ein später beigetretenes Mitglied erhält das Foto durch den Resync', () async {
      final t = await twoMembers('ph-b');
      final photo = await t.p2.service.setOwn(jpegBytes(width: 100, height: 100));
      await t.p2.sync.publishPending();
      await E2e.untilAsync(
        () async => (await t.p1.service.visible(t.g2.userId!))?.id == photo.id,
        what: 'G1 sieht das Foto',
      );

      final g3 = await _login('ph-b3');
      await _join(t.g1, g3);
      final p3 = await _Peer.start(g3);
      peers.add(p3);
      // Der Beitritt löst bei G2 den Resync aus: dasselbe Foto (gleiche ID, gleiches created_at) kommt erneut an.
      await E2e.untilAsync(
        () async => (await p3.service.visible(t.g2.userId!))?.id == photo.id,
        timeout: const Duration(seconds: 60),
        what: 'G3 sieht das Foto durch den Resync',
      );
      expect((await p3.service.visible(t.g2.userId!))!.createdAt, photo.createdAt);
    });

    test(
      '(c) Moderator setzt das Foto zurück; es bleibt zurückgesetzt, auch für ein später beigetretenes Mitglied',
      () async {
        final t = await twoMembers('ph-c');
        final photo = await t.p2.service.setOwn(jpegBytes(width: 90, height: 90));
        await t.p2.sync.publishPending();
        await E2e.untilAsync(
          () async => (await t.p1.service.visible(t.g2.userId!))?.id == photo.id,
          what: 'G1 sieht das Foto',
        );

        await t.p1.service.reset(t.g2.userId!);
        await t.p1.sync.publishPending();
        await E2e.untilAsync(
          () async => await t.p2.service.isResetFor(t.g2.userId!),
          what: 'G2 weiß, dass sein Foto zurückgesetzt wurde',
        );
        expect(await t.p2.service.visible(t.g2.userId!), isNull);

        final g3 = await _login('ph-c3');
        await _join(t.g1, g3);
        final p3 = await _Peer.start(g3);
        peers.add(p3);
        // Der Moderator wiederholt den Reset beim Beitritt; G2 sendet das zurückgesetzte Foto nie erneut.
        await E2e.untilAsync(
          () async => (await p3.store.resets(p3.roomId)).any((r) => r.reset.photoId == photo.id),
          timeout: const Duration(seconds: 60),
          what: 'G3 kennt den Reset',
        );
        expect(await p3.service.visible(t.g2.userId!), isNull);
      },
    );
  });
}
