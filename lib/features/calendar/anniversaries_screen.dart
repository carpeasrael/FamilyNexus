import 'package:flutter/material.dart';

import '../../domain/anniversaries.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../common/error_text.dart';
import 'anniversary_dialog.dart';
import 'calendar_controller.dart';
import 'widgets/anniversary_tile.dart';

/// Geburts- und Gedenktage der Familie (E-104): Liste nach nächstem Vorkommen, anlegen, ändern, löschen.
/// Jedes Familienmitglied darf alles (gemeinsame Familiendaten wie der Einkaufszettel, E-40).
class AnniversariesScreen extends StatelessWidget {
  const AnniversariesScreen({super.key, required this.controller});

  final CalendarController controller;

  Future<void> _edit(BuildContext context, {AnniversaryPerson? existing}) async {
    final l = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    final result = await showAnniversaryDialog(context, today: controller.today, existing: existing);
    if (result == null) return;
    try {
      if (result.delete && existing != null) {
        if (!context.mounted) return;
        if (!await _confirmDelete(context, existing)) return;
        await controller.deleteAnniversary(existing.id);
        m.showSnackBar(SnackBar(content: Text(l.anniversaryDeleted)));
        return;
      }
      if (existing == null) {
        await controller.createAnniversary(name: result.name, birth: result.birth, death: result.death);
      } else {
        await controller.updateAnniversary(existing.id, name: result.name, birth: result.birth, death: result.death);
      }
      m.showSnackBar(SnackBar(content: Text(l.anniversarySaved)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<bool> _confirmDelete(BuildContext context, AnniversaryPerson person) async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.anniversaryDelete),
            content: Text(l.anniversaryDeleteBody(person.name)),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.anniversariesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: Text(l.anniversaryAdd),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final hits = controller.anniversaryUpcoming;
              // Ein Eintrag je Treffer, streng nach nächstem Vorkommen (E-104, #550), wie Karte auf „Heute“ und Agenda.
              return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), children: <Widget>[
                Text(l.anniversariesHint, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (hits.isEmpty) Text(l.anniversariesEmpty),
                for (final h in hits)
                  AnniversaryTile(hit: h, showWhen: true, showDate: true, onTap: () => _edit(context, existing: h.person)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
