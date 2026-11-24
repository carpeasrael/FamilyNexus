/// Familieneinladung oder nicht (#119, K1, B1)? Eine Einladung gilt nur dann als Familieneinladung, wenn sie kein
/// Einzelchat (`is_direct`) und kein Kassenbuch ist und der Raum Beitrittsanfragen verlangt (`join_rule: knock`, E-12,
/// `FamilyRoomSpec`). Eine Gruppe eines fremden Clients (`invite`, `public`, `restricted` …) ist nie die Familie.
///
/// [joinRule] ist `null`, wenn der Server `m.room.join_rules` nicht in den Einladungszustand aufgenommen hat
/// (`room_prejoin_state`): Für die **Anzeige** gilt das wie bisher als Familieneinladung; die Annahme prüft den Zustand
/// nach dem Beitritt vom Server (fail-closed), siehe `acceptInvitation`.
bool isFamilyInvitation({required String? joinRule, required bool isDirect, required bool isBook}) {
  if (isDirect || isBook) return false;
  return joinRule == null || joinRule == knockJoinRule;
}

/// `join_rule` der Familienräume.
const String knockJoinRule = 'knock';
