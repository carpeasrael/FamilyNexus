import 'dart:convert';

import '../../domain/data_inventory.dart';
import '../../domain/event_codec.dart';
import '../../domain/family.dart';
import '../../domain/shopping.dart';
import '../../domain/tasks.dart';
import '../../l10n/gen/app_localizations.dart';

/// Baut die Textprotokolle „lokal gespeicherte Daten“ und „online gespeicherte Daten“. Schlüsselwerte,
/// Zugangstoken und verschlüsselte Inhalte kommen in den Eingangsdaten nicht vor.
class DataReport {
  const DataReport._();

  static String keyStoreText(AppLocalizations l, KeyStoreKind k) => switch (k) {
        KeyStoreKind.androidKeystore => l.keyStoreAndroid,
        KeyStoreKind.appleKeychain => l.keyStoreApple,
        KeyStoreKind.linuxSecretService => l.keyStoreLinux,
        KeyStoreKind.windowsCredentialManager => l.keyStoreWindows,
        KeyStoreKind.browserVault => l.keyStoreBrowser,
      };

  static String _roomKind(AppLocalizations l, InventoryRoomKind k) => switch (k) {
        InventoryRoomKind.family => l.roomKindFamily,
        InventoryRoomKind.private => l.roomKindPrivate,
        InventoryRoomKind.direct => l.roomKindDirect,
        InventoryRoomKind.other => l.roomKindOther,
      };

  /// Eigene Mitgliedschaft laut Matrix (`join`, `invite` …); Unbekanntes bleibt im Original.
  static String _membership(AppLocalizations l, String membership) => switch (membership) {
        'join' => l.reportMembershipJoined,
        'invite' => l.reportMembershipInvited,
        'knock' => l.reportMembershipRequested,
        'leave' => l.reportMembershipLeft,
        'ban' => l.reportMembershipBanned,
        _ => membership,
      };

  static String _memberStatus(AppLocalizations l, MemberStatus s) => switch (s) {
        MemberStatus.joined => l.reportMembershipJoined,
        MemberStatus.invited => l.reportMembershipInvited,
        MemberStatus.requested => l.reportMembershipRequested,
      };

  static String _eventType(AppLocalizations l, String type) {
    final label = switch (type) {
      'm.room.message' => l.eventTypeMessage,
      'm.reaction' => l.eventTypeReaction,
      'm.room.encrypted' => l.eventTypeEncrypted,
      EventCodec.sharedType => l.eventTypeSharedEvent,
      EventCodec.privateType => l.eventTypePrivateEvent,
      EventCodec.rsvpType => l.eventTypeRsvp,
      ShoppingCodec.type => l.eventTypeShopping,
      TaskCodec.listType => l.eventTypeTaskList,
      TaskCodec.logType => l.eventTypeTaskDone,
      _ => null,
    };
    return label == null ? type : '$label ($type)';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String formatTime(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

  static void _heading(StringBuffer b, String text) {
    b
      ..writeln()
      ..writeln('== $text ==');
  }

  static void _header(StringBuffer b, AppLocalizations l, String title, DateTime now, String version) {
    b
      ..writeln('${l.appName} – $title')
      ..writeln(l.reportGenerated(formatTime(now), version));
  }

  static void _locations(StringBuffer b, AppLocalizations l, StorageLocations loc, String? server) {
    _heading(b, l.settingsStorageTitle);
    b.writeln('${l.settingsStorageDbDir}: ${loc.inBrowser ? l.settingsStorageBrowser : loc.databaseDirectory}');
    b.writeln('${l.settingsStorageAppDb}: ${loc.appDatabase}');
    b.writeln('${l.settingsStorageMatrixDb}: ${loc.matrixDatabase}');
    b.writeln('${l.settingsStorageKeys}: ${keyStoreText(l, loc.keyStore)}');
    if (server != null) b.writeln('${l.settingsStorageOnline}: $server');
  }

  static void _rooms(StringBuffer b, AppLocalizations l, List<InventoryRoom> rooms, {required bool withMembers}) {
    if (rooms.isEmpty) b.writeln(l.reportNone);
    for (final r in rooms) {
      b
        ..writeln()
        ..writeln('- ${_roomKind(l, r.kind)}${r.name.isEmpty ? '' : ' „${r.name}“'} (${r.id})');
      if (withMembers) {
        b
          ..writeln('  ${l.reportRoomEncrypted}: ${r.encrypted ? l.reportYes : l.reportNo}')
          ..writeln('  ${l.reportRoomMembership}: ${_membership(l, r.membership)}')
          ..writeln('  ${l.reportRoomMembers(r.joinedMembers, r.invitedMembers)}');
      }
      b.writeln('  ${l.reportRoomEvents(r.cachedEvents)}');
      final types = r.eventTypes.entries.toList()..sort((a, c) => c.value.compareTo(a.value));
      for (final e in types) {
        b.writeln('    ${_eventType(l, e.key)}: ${e.value}');
      }
      if (r.attachments > 0) b.writeln('  ${l.reportRoomAttachments(r.attachments)}');
    }
  }

  static const JsonEncoder _json = JsonEncoder.withIndent('  ');

  /// Ein Wert der App-Datenbank; JSON-Text wird lesbar eingerückt.
  static String _value(Object? v) {
    if (v is String && (v.startsWith('{') || v.startsWith('['))) {
      try {
        return _json.convert(json.decode(v)).replaceAll('\n', '\n      ');
      } on FormatException {
        return v;
      }
    }
    return '$v';
  }

  /// Protokoll aller lokal gespeicherten Daten. [matrix] stammt aus dem Matrix-Zwischenspeicher
  /// (ohne Netzabfrage); `null`, wenn nicht angemeldet.
  static String local({
    required AppLocalizations l,
    required LocalInventory inventory,
    required OnlineInventory? matrix,
    required DateTime now,
    required String version,
  }) {
    final b = StringBuffer();
    _header(b, l, l.reportLocalTitle, now, version);
    _locations(b, l, inventory.locations, null);

    _heading(b, l.reportSectionKeys);
    for (final k in inventory.keys) {
      b.writeln('- ${k.name}: ${k.present ? l.reportKeyPresent : l.reportKeyMissing}');
    }

    _heading(b, l.reportSectionAppDb);
    b.writeln(l.reportFile(inventory.locations.appDatabase));
    final appSize = inventory.appDatabaseBytes;
    if (appSize != null) b.writeln(l.reportFileSize(formatBytes(appSize)));
    for (final t in inventory.tables) {
      b
        ..writeln()
        ..writeln('-- ${t.name}: ${l.reportRows(t.rows.length)} --');
      for (final row in t.rows) {
        b.writeln('* ${row.entries.map((e) => '${e.key}=${_value(e.value)}').join('\n    ')}');
      }
    }

    _heading(b, l.reportSectionMatrixDb);
    b.writeln(l.reportFile(inventory.locations.matrixDatabase));
    final matrixSize = inventory.matrixDatabaseBytes;
    if (matrixSize != null) b.writeln(l.reportFileSize(formatBytes(matrixSize)));
    if (matrix == null) {
      b.writeln(l.reportMatrixUnavailable);
    } else {
      b.writeln('${l.accountUsername}: ${matrix.userId} (${matrix.deviceId})');
      b.writeln('${l.reportSectionAccountData}: ${matrix.accountDataTypes.isEmpty ? l.reportNone : matrix.accountDataTypes.join(', ')}');
      _rooms(b, l, matrix.rooms, withMembers: false);
      b
        ..writeln()
        ..writeln(l.reportMatrixSecrets);
    }

    b.writeln();
    b.writeln(l.reportMemoryOnly);
    if (!inventory.locations.inBrowser) b.writeln(l.reportOsReminders);
    return b.toString();
  }

  /// Protokoll aller beim Matrix-Anbieter gespeicherten Daten des Kontos.
  static String online({
    required AppLocalizations l,
    required OnlineInventory inventory,
    required DateTime now,
    required String version,
  }) {
    final b = StringBuffer();
    _header(b, l, l.reportOnlineTitle, now, version);
    b
      ..writeln()
      ..writeln(l.reportOnlineNote);

    _heading(b, l.reportSectionAccount);
    b
      ..writeln('${l.settingsServer}: ${inventory.server}')
      ..writeln('${l.accountUsername}: ${inventory.userId}')
      ..writeln('${l.reportDisplayName}: ${inventory.displayName ?? l.reportNotSet}')
      ..writeln('${l.reportAvatar}: ${inventory.hasAvatar ? l.reportYes : l.reportNo}');

    _heading(b, l.securityDevices);
    if (inventory.devices.isEmpty) b.writeln(l.reportNone);
    for (final d in inventory.devices) {
      final state = d.verified ? l.securityDeviceVerified : l.securityDeviceUnverified;
      b.writeln('- ${d.name} (${d.deviceId}) – $state${d.isCurrent ? ' – ${l.securityDeviceThis}' : ''}');
    }

    _heading(b, l.reportSectionSecurity);
    b
      ..writeln('${l.reportCrossSigning}: ${inventory.crossSigning ? l.reportSetUp : l.reportNotSetUp}')
      ..writeln('${l.reportKeyBackup}: ${inventory.keyBackup ? l.reportSetUp : l.reportNotSetUp}');

    _heading(b, l.reportSectionAccountData);
    if (inventory.accountDataTypes.isEmpty) b.writeln(l.reportNone);
    for (final t in inventory.accountDataTypes) {
      b.writeln('- $t');
    }

    final family = inventory.family;
    if (family != null) {
      _heading(b, '${l.reportFamilyMembers} „${family.name}“');
      for (final m in family.members) {
        final role = m.role == Role.moderator ? l.familyRoleModerator : l.familyRoleMember;
        b.writeln('- ${m.displayName} (${m.userId}) – $role – ${_memberStatus(l, m.status)}');
      }
    }

    _heading(b, l.reportSectionRooms);
    _rooms(b, l, inventory.rooms, withMembers: true);
    return b.toString();
  }
}
