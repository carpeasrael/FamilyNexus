import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../core/platform_info.dart';
import '../../domain/shopping.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/length_limit.dart';
import '../chat/sender_name.dart';
import '../common/error_text.dart';
import 'shopping_controller.dart';

part 'widgets/shopping_parts.dart';

/// Gemeinsamer Einkaufszettel der Familie (E-40).
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _group = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _groupFocus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _qty.dispose();
    _group.dispose();
    _titleFocus.dispose();
    _groupFocus.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add(ShoppingController c) async {
    final l = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) return;
    try {
      await c.add(_title.text, quantity: _qty.text, group: _group.text);
      _title.clear();
      _qty.clear();
      // Die Gruppe bleibt stehen: Oft kommen mehrere Einträge für dasselbe Geschäft (#211).
      _titleFocus.requestFocus();
    } catch (e) {
      _toast(errorText(l, e));
    }
  }

  Future<void> _run(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    try {
      await op();
    } catch (e) {
      _toast(errorText(l, e));
    }
  }

  Future<void> _edit(ShoppingController c, ShoppingItem item) async {
    final names = c.groupNames;
    final result = await showDialog<({String title, String quantity, String group})>(
      context: context,
      builder: (d) => _EditDialog(item: item, groupNames: names),
    );
    if (result != null && mounted) {
      await _run(() => c.edit(item.id, title: result.title, quantity: result.quantity, group: result.group));
    }
  }

  Future<void> _clearDone(ShoppingController c) async {
    final l = AppLocalizations.of(context);
    final n = c.done.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l.shoppingClearConfirm(n)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.shoppingClearDone)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final removed = await c.clearChecked();
      _toast(l.shoppingCleared(removed));
    } catch (e) {
      _toast(errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final c = services.shopping;
    final l = AppLocalizations.of(context);
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[c, services.gateway]),
      builder: (context, _) {
        // Der Name steht nur in „zuletzt von {name}“, also im Satz (#326).
        String nameOf(String id) => memberLabel(l, services.gateway.family, id, me: c.me, inSentence: true);
        Widget tile(ShoppingItem i) => _ItemTile(
              item: i,
              by: nameOf(i.by),
              byMe: i.by == c.me,
              onToggle: () => _run(() => c.setChecked(i.id, !i.checked)),
              onEdit: () => _edit(c, i),
              onDelete: () => _run(() => c.remove(i.id)),
            );
        // Das Formular darf nie die ganze Höhe belegen: Im Querformat mit Tastatur scrollt es, die Liste
        // behält den Rest (#211). Es gehört zur Eingabe, Tippen und Ziehen darin lässt die Tastatur offen.
        return LayoutBuilder(
          builder: (context, box) => Column(children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.6),
              child: _AddForm(
                title: _title,
                quantity: _qty,
                group: _group,
                titleFocus: _titleFocus,
                groupFocus: _groupFocus,
                groupNames: c.groupNames,
                onAdd: () => _add(c),
              ),
            ),
            Expanded(
              child: _ShoppingList(
                open: c.open,
                done: c.done,
                groups: c.openGroups,
                tile: tile,
                onClearDone: () => _clearDone(c),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Höchstzahl der Vorschlag-Chips; weitere Gruppen erreicht man durch Tippen (#211).
const int maxGroupChips = 6;
