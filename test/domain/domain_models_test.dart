import 'dart:typed_data';

import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage', () {
    final base = ChatMessage(
      id: r'$a',
      senderId: '@a:x.org',
      senderName: 'Anna',
      time: DateTime.utc(2026),
      body: 'Hallo',
      attachment: const AttachmentInfo(name: 'a.png', mimeType: 'image/png', size: 5),
      sharedEventId: 'e',
      blockedAttachment: true,
      undecryptable: true,
    );

    test('copyWith ändert nur Reaktionen und Status', () {
      final c = base.copyWith(
        reactions: <String, Set<String>>{'👍': <String>{'@b:x.org'}},
        status: MessageStatus.failed,
      );
      expect(c.reactions['👍'], <String>{'@b:x.org'});
      expect(c.status, MessageStatus.failed);
      expect(c.body, 'Hallo');
      expect(c.attachment!.isImage, isTrue);
      expect(c.sharedEventId, 'e');
      expect(c.blockedAttachment, isTrue);
      expect(c.undecryptable, isTrue);
      expect(base.copyWith().status, MessageStatus.sent);
    });

    test('Anhang, der kein Bild ist', () {
      expect(const AttachmentInfo(name: 'a.pdf', mimeType: 'application/pdf', size: 1).isImage, isFalse);
    });
  });

  group('FamilyMember / Family', () {
    const m = FamilyMember(userId: '@a:x.org', displayName: 'Anna', role: Role.member);

    test('copyWith, Gleichheit, Hashcode', () {
      final c = m.copyWith(role: Role.moderator, status: MemberStatus.invited, displayName: 'A');
      expect(c.role, Role.moderator);
      expect(c.status, MemberStatus.invited);
      expect(c.displayName, 'A');
      expect(m.copyWith(), m);
      expect(m.copyWith().hashCode, m.hashCode);
      expect(c == m, isFalse);
    });

    test('Familie: joined/requests/Moderatorzahl/Empfehlung', () {
      final f = Family(
        roomId: '!r:x.org',
        name: 'F',
        myUserId: '@a:x.org',
        members: <FamilyMember>[
          m.copyWith(role: Role.moderator),
          const FamilyMember(userId: '@b:x.org', displayName: 'B', role: Role.moderator),
        ],
      );
      expect(f.moderatorCount, 2);
      expect(f.needsSecondModerator, isFalse);
      expect(f.member('@zz:x.org'), isNull);
    });

    test('Einladung (Wert)', () {
      const i = PendingInvitation(roomId: '!r:x.org', roomName: 'F', inviterId: '@a:x.org');
      expect(i.roomName, 'F');
    });
  });

  group('Server', () {
    test('IP-Adressen und IPv6 werden akzeptiert/abgelehnt', () {
      expect(ServerUrl.tryParse('https://192.168.1.5:8448'), isNotNull);
      expect(ServerUrl.tryParse('https://[::1]:8448'), isNotNull);
      expect(ServerUrl.tryParse('https://example.com:0'), isNull);
    });

    test('Gleichheit und Info', () {
      final a = ServerUrl.tryParse('example.org')!;
      expect(a, ServerUrl.tryParse('https://example.org/'));
      expect(a.hashCode, ServerUrl.tryParse('EXAMPLE.org')!.hashCode);
      final info = ServerInfo(url: a, versions: const <String>['v1.1'], supportsPasswordLogin: true, contact: 'x', supportPage: 'https://x');
      expect(info.contact, 'x');
      expect(info.supportPage, 'https://x');
      expect(a.host, 'example.org');
    });
  });

  group('Anhang-Signaturen', () {
    Uint8List b(List<int> x) => Uint8List.fromList(x);
    test('gif/webp/pdf/jpeg', () {
      expect(AttachmentPolicy.check(fileName: 'a.gif', bytes: b(<int>[0x47, 0x49, 0x46, 0x38, 0])), isNull);
      expect(AttachmentPolicy.check(fileName: 'a.webp', bytes: b(<int>[0x52, 0x49, 0x46, 0x46, 0])), isNull);
      expect(AttachmentPolicy.check(fileName: 'a.pdf', bytes: b(<int>[0x25, 0x50, 0x44, 0x46, 0])), isNull);
      expect(AttachmentPolicy.check(fileName: 'a.jpg', bytes: b(<int>[0xFF, 0xD8, 0xFF, 0])), isNull);
      expect(AttachmentPolicy.check(fileName: 'a.gif', bytes: b(<int>[1, 2, 3, 4])), AttachmentRejection.contentMismatch);
      expect(AttachmentPolicy.check(fileName: 'a.webp', bytes: b(<int>[1, 2, 3, 4])), AttachmentRejection.contentMismatch);
      expect(AttachmentPolicy.check(fileName: 'a.txt', bytes: b(<int>[104, 105])), isNull);
    });
    test('Dateiname nur mit Punkt am Ende hat keinen Typ', () {
      expect(AttachmentPolicy.mimeForName('a.'), isNull);
      expect(AttachmentPolicy.mimeForName('abc'), isNull);
    });
  });

  test('Sicherheitsmodelle', () {
    const d = DeviceEntry(userId: '@a:x.org', deviceId: 'D', name: 'Gerät', verified: true, isCurrent: true);
    expect(d.verified && d.isCurrent, isTrue);
    const v = VerificationInfo(phase: VerificationPhase.comparing, peerUserId: '@a:x.org', emojis: <VerificationEmoji>[VerificationEmoji(emoji: '🐶', name: 'Dog')]);
    expect(v.emojis.single.name, 'Dog');
    expect(v.incoming, isFalse);
    expect(SecurityState.values, contains(SecurityState.ready));
  });
}
