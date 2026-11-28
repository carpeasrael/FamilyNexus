import 'chat.dart';
import 'contacts.dart' show ContactLimits;
import 'family.dart' show PowerLevels;

/// Was ich in einer Gruppe darf (#119, K4-1, KONTAKTE §8.5), aus den Stufen des **Raumzustands** (nie aus Datensätzen).
/// Reine Regel ohne SDK; der Server prüft ohnehin, die App erlaubt nur, was der Zustand erlaubt. Aufrufer: das Gruppenmodul des
/// Gateways (K4-3).
///
/// Admin ist, wer mindestens Stufe 50 hat; ernannt wird auf höchstens 50 (nie 100).
class GroupRights {
  const GroupRights({
    required this.myUserId,
    required this.myLevel,
    this.inviteLevel = PowerLevels.moderator,
    this.kickLevel = PowerLevels.moderator,
    this.nameLevel = PowerLevels.moderator,
    this.powerLevelsLevel = PowerLevels.moderator,
  });

  final String myUserId;

  /// Meine Stufe im Raum.
  final int myLevel;

  /// Schwellen aus dem Raumzustand (`invite`, `kick`, `m.room.name`, `m.room.power_levels`).
  final int inviteLevel;
  final int kickLevel;
  final int nameLevel;
  final int powerLevelsLevel;

  bool get isAdmin => myLevel >= PowerLevels.moderator;

  bool get canInvite => myLevel >= inviteLevel;

  /// Umbenennen nur mit der Schwelle von `m.room.name`.
  bool get canRename => myLevel >= nameLevel;

  /// Entfernen: Schwelle erreicht, nie ich selbst (dafür gibt es Verlassen), nie jemand mit Stufe ≥ meiner.
  bool canRemove(String targetUserId, int targetLevel) =>
      myLevel >= kickLevel && targetUserId != myUserId && targetLevel < myLevel;

  /// Stufe ändern (Admin ernennen oder entziehen): Schwelle von `m.room.power_levels` erreicht; für andere nur bei
  /// Stufe unter meiner; für mich selbst nur die Selbstabstufung. Ernennen nur, wer unter 50 ist, entziehen nur, wer
  /// mindestens 50 hat.
  bool canSetAdmin(String targetUserId, int targetLevel, {required bool admin}) {
    if (myLevel < powerLevelsLevel) return false;
    final self = targetUserId == myUserId;
    if (self && admin) return false;
    if (!self && targetLevel >= myLevel) return false;
    return admin ? targetLevel < PowerLevels.moderator : targetLevel >= PowerLevels.moderator;
  }

  /// Zielstufe beim Ernennen (50, nie 100) bzw. Entziehen (0).
  static int levelFor({required bool admin}) => admin ? PowerLevels.moderator : PowerLevels.member;

  /// Bin ich der letzte beigetretene Admin? Nur beigetretene Mitglieder mit Stufe ≥ 50 zählen; ohne Eintrag für mich liefert
  /// die Funktion `false`. Beim **Verlassen** ist das nur eine Warnung (K4-4), keine Sperre. Das Gateway nutzt sie **zusätzlich als
  /// Sperre der Selbstabstufung** (K4-3, `setGroupAdmin`): der einzige Admin darf sich nicht abstufen. [canSetAdmin] bleibt dafür
  /// unverändert.
  static bool isLastAdmin(Iterable<GroupMember> members) {
    var meAdmin = false;
    for (final m in members) {
      if (m.membership != GroupMembership.join || m.power < PowerLevels.moderator) continue;
      if (!m.isMe) return false;
      meAdmin = true;
    }
    return meAdmin;
  }
}

/// Laufende Prüfung einer Gruppe auf Sendefähigkeit (#119, K4-1, §3.6): reine Funktion über den Raumzustand.
class GroupHealth {
  const GroupHealth._();

  /// Größenmaß G = beigetreten + (eingeladen ?? 0); „zu groß“ ab G > 50 (Eingeladene lesen ab Einladung mit). Eine
  /// unbekannte Einladungszahl zählt 0 (bewusst leicht fail-open, nach einem Mitgliederabruf ist G exakt); eine unbekannte
  /// Beitrittszahl ist „Größe unbekannt“ (fail-closed).
  static int? size({required int? joined, required int? invited}) => joined == null ? null : joined + (invited ?? 0);

  /// [GroupSendLock.keiner] heißt: keine Sperre aus dem Raumzustand. Reihenfolge der Gründe: Verschlüsselung, Regel,
  /// Verlauf (unbekannte Werte zählen als geöffnet, fail-closed), unbekannte Größe, zu groß. Die Gründe
  /// `keineMitglieder` und `wechsel` kennt diese Funktion nicht, sie stammen aus dem Gateway-Zustand. Verlassen ist nie
  /// gesperrt, auch nicht bei einem Sperrgrund.
  static GroupSendLock evaluate({
    required bool megolm,
    required String? joinRule,
    required String? historyVisibility,
    required int? joined,
    required int? invited,
  }) {
    if (!megolm) return GroupSendLock.unverschluesselt;
    if (joinRule != 'invite') return GroupSendLock.regelGeaendert;
    if (historyVisibility != 'invited') return GroupSendLock.verlaufGeoeffnet;
    final g = size(joined: joined, invited: invited);
    if (g == null) return GroupSendLock.groesseUnbekannt;
    if (g > ContactLimits.maxGroupMembers) return GroupSendLock.zuGross;
    return GroupSendLock.keiner;
  }
}
