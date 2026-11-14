import 'package:flutter/material.dart';

import '../../core/contrast.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';

/// Aussehen eines eingebauten Avatars: Symbol auf einer Farbfläche aus der Palette der Personenfarben.
typedef AvatarPresetStyle = ({IconData icon, int colorIndex});

/// Abbildung der zwölf Kennungen (`p01`…`p12`, siehe `AvatarPresets`) auf Symbol, Farbe und Namen (#422).
class AvatarPresetsUi {
  const AvatarPresetsUi._();

  static const Map<String, AvatarPresetStyle> styles = <String, AvatarPresetStyle>{
    'p01': (icon: Icons.pets, colorIndex: 0),
    'p02': (icon: Icons.cruelty_free, colorIndex: 1),
    'p03': (icon: Icons.flutter_dash, colorIndex: 2),
    'p04': (icon: Icons.local_florist, colorIndex: 3),
    'p05': (icon: Icons.park, colorIndex: 5),
    'p06': (icon: Icons.sailing, colorIndex: 4),
    'p07': (icon: Icons.directions_bike, colorIndex: 6),
    'p08': (icon: Icons.local_pizza, colorIndex: 7),
    'p09': (icon: Icons.icecream, colorIndex: 1),
    'p10': (icon: Icons.music_note, colorIndex: 3),
    'p11': (icon: Icons.sports_soccer, colorIndex: 0),
    'p12': (icon: Icons.rocket_launch, colorIndex: 2),
  };

  /// Hintergrundfarbe des Avatars.
  static Color background(AvatarPresetStyle s) => AuroraTokens.personColors[s.colorIndex % AuroraTokens.personColors.length];

  static const Color _dark = Color(0xFF0B1120);
  static const Color _light = Color(0xFFFFFFFF);

  /// Schwarz oder Weiß, je nachdem, was gegen [bg] den besseren Kontrast hat (wie die Schrift auf der Primärfarbe, E-46).
  static Color foregroundOn(Color bg) => contrastRatio(_dark, bg) >= contrastRatio(_light, bg) ? _dark : _light;

  /// Name für Auswahl und Screenreader; unbekannte Kennungen heißen wie „kein Avatar“.
  static String name(AppLocalizations l, String preset) => switch (preset) {
        'p01' => l.avatarPreset01,
        'p02' => l.avatarPreset02,
        'p03' => l.avatarPreset03,
        'p04' => l.avatarPreset04,
        'p05' => l.avatarPreset05,
        'p06' => l.avatarPreset06,
        'p07' => l.avatarPreset07,
        'p08' => l.avatarPreset08,
        'p09' => l.avatarPreset09,
        'p10' => l.avatarPreset10,
        'p11' => l.avatarPreset11,
        'p12' => l.avatarPreset12,
        _ => l.avatarInitials,
      };
}
