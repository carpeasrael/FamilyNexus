import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/event_themes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/length_limit.dart';
import '../common/error_text.dart';
import 'calendar_controller.dart';

/// Name der Themenfarbe (Palettenindex); Himmelblau ist nur der Vollständigkeit halber benannt, es ist als
/// Themenfarbe nicht wählbar (E-99).
String themeColorLabel(AppLocalizations l, int index) => switch (index) {
      0 => l.themeColorTeal,
      1 => l.themeColorPink,
      2 => l.themeColorViolet,
      3 => l.themeColorSky,
      4 => l.themeColorAmber,
      5 => l.themeColorGreen,
      6 => l.themeColorOrange,
      _ => l.themeColorRed,
    };

/// Kalender-Themen verwalten (nur Moderatoren, E-99): anlegen, umbenennen, Farbe ändern, löschen.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key, required this.controller});

  final CalendarController controller;

  Future<void> _edit(BuildContext context, {EventTheme? existing}) async {
    final l = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    final result = await showDialog<({String name, int color})>(
      context: context,
      builder: (_) => _ThemeDialog(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await controller.createTheme(name: result.name, colorIndex: result.color);
      } else {
        await controller.updateTheme(existing.id, name: result.name, colorIndex: result.color);
      }
      m.showSnackBar(SnackBar(content: Text(l.themeSaved)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<void> _delete(BuildContext context, EventTheme theme) async {
    final l = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.themeDelete),
            content: Text(l.themeDeleteBody(theme.name)),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await controller.deleteTheme(theme.id);
      m.showSnackBar(SnackBar(content: Text(l.themeDeleted)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.familyThemes)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: Text(l.themeAdd),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final themes = controller.eventThemes;
              return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), children: <Widget>[
                Text(l.familyThemesHint, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (themes.isEmpty) Text(l.themesEmpty),
                for (final th in themes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: <Widget>[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(color: AuroraTokens.personColors[th.colorIndex], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text(th.name, style: Theme.of(context).textTheme.titleMedium),
                            Text(themeColorLabel(l, th.colorIndex), style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        IconButton(tooltip: l.themeEdit, icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, existing: th)),
                        IconButton(tooltip: l.themeDelete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, th)),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _ThemeDialog extends StatefulWidget {
  const _ThemeDialog({this.existing});
  final EventTheme? existing;

  @override
  State<_ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<_ThemeDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late int _color = widget.existing?.colorIndex ?? EventTheme.selectableColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l.themeAdd : l.themeEdit),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: EventTheme.maxName,
            inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(EventTheme.maxName, LengthMeasure.codePoints)],
            buildCounter: measuredCounter(_name, EventTheme.maxName, LengthMeasure.codePoints),
            textCapitalization: TextCapitalization.sentences,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: l.themeName),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 8),
          Text(l.themeColor, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          // Himmelblau gehört „privat“ und ist nicht wählbar; Farbe immer mit Namen, nie nur als Farbe.
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            for (final i in EventTheme.selectableColors)
              ChoiceChip(
                avatar: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AuroraTokens.personColors[i],
                    shape: BoxShape.circle,
                    border: Border.all(color: t.textPrimary.withValues(alpha: 0.4)),
                  ),
                ),
                label: Text(themeColorLabel(l, i)),
                selected: _color == i,
                onSelected: (_) => setState(() => _color = i),
              ),
          ]),
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _confirm, child: Text(l.save)),
      ],
    );
  }
}
