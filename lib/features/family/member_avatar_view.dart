import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/family.dart';
import '../../ui/theme/tokens.dart';
import '../presence/presence_view.dart';
import 'avatar_presets_ui.dart';

/// Avatar eines Familienmitglieds (#422, E-101): der gewählte eingebaute Avatar, sonst ein Kreis in der Personenfarbe
/// mit dem Anfangsbuchstaben des Anzeigenamens. Gezeigt wird die Wahl nur für beigetretene Mitglieder.
///
/// * [colorIndex]: Personenfarbe (Palettenindex); die Aufrufer reichen `colorIndexFor` oder
///   `AuroraTokens.personColorFallback` durch.
/// * [ring]: setzt die Personenfarbe als Rand (Kalender: Termine bleiben unterscheidbar).
/// * [online]: optionaler Online-Punkt am Avatar (ersetzt den eigenen Punkt; der Text steht daneben).
///
/// Der Avatar ist dekorativ ([ExcludeSemantics]): der Name steht an jeder Stelle daneben, nie nur das Bild. Ohne
/// `AppScope` (Widget-Tests) erscheint der Rückfall in der übergebenen Farbe mit `?`.
class MemberAvatarView extends StatelessWidget {
  MemberAvatarView({
    required this.userId,
    required this.size,
    required this.colorIndex,
    this.online,
    this.ring = false,
  }) : super(key: ValueKey<String>('avatar-$userId'));

  final String userId;
  final double size;
  final int colorIndex;
  final bool? online;
  final bool ring;

  /// Ab dieser Größe (einschließlich) zeichnet der Rückfall den Buchstaben; kleinere bleiben ein einfarbiger Kreis.
  static const double letterMinSize = 20;

  /// Kontrast, den Buchstabe und Symbol auf der Farbfläche mindestens erreichen (WCAG: Text 4,5, Symbol 3).
  static const double letterContrast = 4.5;
  static const double iconContrast = 3;

  @override
  Widget build(BuildContext context) {
    final gateway = AppScope.maybeOf(context)?.gateway;
    if (gateway == null) return _build(context, preset: null, letter: '?');
    return ListenableBuilder(
      listenable: gateway.avatarRevision,
      builder: (context, _) {
        final family = gateway.family;
        final member = family?.member(userId);
        // Ohne Familie (noch nicht aufgebaut) ist der Beitrittsstatus unbekannt und gilt als beigetreten.
        final joined = family == null || member?.status == MemberStatus.joined;
        final preset = joined ? gateway.avatarOf(userId) : null;
        final name = member?.displayName ?? '';
        return _build(context, preset: preset, letter: name.isEmpty ? '?' : _initial(name));
      },
    );
  }

  static String _initial(String name) => name.characters.first.toUpperCase();

  Widget _build(BuildContext context, {required String? preset, required String letter}) {
    final person = AuroraTokens.personColors[colorIndex % AuroraTokens.personColors.length];
    final style = preset == null ? null : AvatarPresetsUi.styles[preset];
    final bg = style == null ? person : AvatarPresetsUi.background(style);
    final fg = AvatarPresetsUi.foregroundOn(bg);
    final borderWidth = size >= letterMinSize ? 2.0 : 1.5;
    Widget face = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: ring ? Border.all(color: person, width: borderWidth) : null,
      ),
      child: Center(
        child: style != null
            ? Icon(style.icon, size: size * 0.6, color: fg)
            : (size >= letterMinSize
                ? Text(letter, style: TextStyle(color: fg, fontSize: size * 0.5, fontWeight: FontWeight.w600, height: 1))
                : null),
      ),
    );
    face = ExcludeSemantics(child: SizedBox(width: size, height: size, child: face));
    final dot = online;
    if (dot == null) return face;
    final dotSize = size >= 40 ? 12.0 : 10.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        face,
        Positioned(right: -2, bottom: -2, child: PresenceDot(online: dot, size: dotSize)),
      ]),
    );
  }
}
