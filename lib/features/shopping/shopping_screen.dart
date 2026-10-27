import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/platform_info.dart';
import '../../domain/shopping.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'shopping_controller.dart';

/// Gemeinsamer Einkaufszettel der Familie (E-40).
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _qty.dispose();
    _titleFocus.dispose();
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
      await c.add(_title.text, quantity: _qty.text);
      _title.clear();
      _qty.clear();
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
    final result = await showDialog<({String title, String quantity})>(
      context: context,
      builder: (d) => _EditDialog(item: item),
    );
    if (result != null && mounted) await _run(() => c.edit(item.id, title: result.title, quantity: result.quantity));
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
        final open = c.open;
        final done = c.done;
        String nameOf(String id) => id == c.me ? l.chatYou : (services.gateway.family?.member(id)?.displayName ?? id);
        return Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              const Icon(Icons.lock_outline, size: 14),
              const SizedBox(width: 4),
              Flexible(child: Text(l.shoppingNote, style: Theme.of(context).textTheme.labelSmall)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _title,
                  focusNode: _titleFocus,
                  maxLength: ShoppingItem.maxTitle,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  enableIMEPersonalizedLearning: false,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(hintText: l.shoppingHintItem),
                  // Desktop: Enter fügt hinzu; mobil springt „Weiter“ zur Menge (#37).
                  onSubmitted: PlatformInfo.enterSubmits ? (_) => _add(c) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _qty,
                  maxLength: ShoppingItem.maxQuantity,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  enableIMEPersonalizedLearning: false,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: l.shoppingHintQuantity),
                  onSubmitted: (_) => _add(c),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(tooltip: l.shoppingAdd, icon: const Icon(Icons.add), onPressed: () => _add(c)),
            ]),
          ),
          Expanded(
            child: open.isEmpty && done.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.shoppingEmpty, textAlign: TextAlign.center)))
                : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: <Widget>[
                    if (open.isNotEmpty) ...<Widget>[
                      _Header(l.shoppingOpenHeader(open.length)),
                      for (final i in open)
                        _ItemTile(
                          item: i,
                          by: nameOf(i.by),
                          onToggle: () => _run(() => c.setChecked(i.id, true)),
                          onEdit: () => _edit(c, i),
                          onDelete: () => _run(() => c.remove(i.id)),
                        ),
                    ],
                    if (done.isNotEmpty) ...<Widget>[
                      Row(children: <Widget>[
                        Expanded(child: _Header(l.shoppingDoneHeader(done.length))),
                        TextButton.icon(icon: const Icon(Icons.delete_sweep_outlined), label: Text(l.shoppingClearDone), onPressed: () => _clearDone(c)),
                      ]),
                      for (final i in done)
                        _ItemTile(
                          item: i,
                          by: nameOf(i.by),
                          onToggle: () => _run(() => c.setChecked(i.id, false)),
                          onEdit: () => _edit(c, i),
                          onDelete: () => _run(() => c.remove(i.id)),
                        ),
                    ],
                  ]),
          ),
        ]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.by, required this.onToggle, required this.onEdit, required this.onDelete});
  final ShoppingItem item;
  final String by;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final style = item.checked
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(decoration: TextDecoration.lineThrough, color: t.textSecondary)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(children: <Widget>[
          Semantics(
            label: item.checked ? l.shoppingMarkOpen(item.title) : l.shoppingMarkDone(item.title),
            child: Checkbox(value: item.checked, onChanged: (_) => onToggle()),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(item.title, style: style),
              Text(l.shoppingLastBy(by), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
            ]),
          ),
          if (item.quantity.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: StatusBadge(label: item.quantity, color: t.primary),
            ),
          PopupMenuButton<String>(
            tooltip: item.title,
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text(l.shoppingEdit)),
              PopupMenuItem<String>(value: 'delete', child: Text(l.shoppingDelete)),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Bearbeiten-Dialog; die Eingabefelder gehören dem Dialog (kein Zugriff nach dem Schließen).
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.item});
  final ShoppingItem item;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.item.title);
  late final TextEditingController _qty = TextEditingController(text: widget.item.quantity);

  @override
  void dispose() {
    _title.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.shoppingEditTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: ShoppingItem.maxTitle,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.shoppingHintItem),
        ),
        TextField(
          controller: _qty,
          maxLength: ShoppingItem.maxQuantity,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.shoppingHintQuantity),
        ),
      ]),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, (title: _title.text, quantity: _qty.text)), child: Text(l.save)),
      ],
    );
  }
}
