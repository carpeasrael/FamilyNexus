part of '../shopping_screen.dart';

/// Eingabe eines Eintrags: Hinweis, Titel, Menge, Gruppe mit Vorschlägen und „Hinzufügen“. Scrollt, damit sie nie die
/// ganze Höhe belegt (#211).
class _AddForm extends StatelessWidget {
  const _AddForm({
    required this.title,
    required this.quantity,
    required this.group,
    required this.titleFocus,
    required this.groupFocus,
    required this.groupNames,
    required this.onAdd,
  });
  final TextEditingController title;
  final TextEditingController quantity;
  final TextEditingController group;
  final FocusNode titleFocus;
  final FocusNode groupFocus;
  final List<String> groupNames;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      primary: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: TextFieldTapRegion(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: <Widget>[
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: title,
                    focusNode: titleFocus,
                    maxLength: ShoppingItem.maxTitle,
                    inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(ShoppingItem.maxTitle, LengthMeasure.codePoints)],
                    buildCounter: _noCounter,
                    enableIMEPersonalizedLearning: false,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(hintText: l.shoppingHintItem),
                    // Desktop: Enter fügt hinzu; mobil springt „Weiter“ zur Menge (#37).
                    onSubmitted: PlatformInfo.enterSubmits ? (_) => onAdd() : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: quantity,
                    maxLength: ShoppingItem.maxQuantity,
                    inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(ShoppingItem.maxQuantity, LengthMeasure.codePoints)],
                    buildCounter: _noCounter,
                    enableIMEPersonalizedLearning: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(hintText: l.shoppingHintQuantity),
                    // Mobil springt „Weiter“ zur Gruppe, Hinzufügen liegt dort oder am Knopf (#211).
                    onSubmitted: PlatformInfo.enterSubmits ? (_) => onAdd() : null,
                  ),
                ),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Expanded(
                  child: _GroupTextField(
                    controller: group,
                    focusNode: groupFocus,
                    buildCounter: _noCounter,
                    decoration: InputDecoration(hintText: l.shoppingHintGroup),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(tooltip: l.shoppingAdd, icon: const Icon(Icons.add), onPressed: onAdd),
              ]),
              _GroupChips(names: groupNames, controller: group, focusNode: groupFocus),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Offene Einträge (nach Gruppen) und erledigte Einträge; leer: Hinweis.
class _ShoppingList extends StatelessWidget {
  const _ShoppingList({required this.open, required this.done, required this.groups, required this.tile, required this.onClearDone});
  final List<ShoppingItem> open;
  final List<ShoppingItem> done;
  final List<ShoppingGroup> groups;
  final Widget Function(ShoppingItem item) tile;
  final VoidCallback onClearDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (open.isEmpty && done.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.shoppingEmpty, textAlign: TextAlign.center)));
    }
    final named = groups.any((g) => g.label != null);
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: <Widget>[
      if (open.isNotEmpty) ...<Widget>[
        _Header(l.shoppingOpenHeader(open.length)),
        for (final g in groups) ...<Widget>[
          if (named) _GroupHeader(g.label == null ? l.shoppingNoGroup(g.items.length) : l.shoppingGroupHeader(g.label!, g.items.length)),
          for (final i in g.items) tile(i),
        ],
      ],
      if (done.isNotEmpty) ...<Widget>[
        Row(children: <Widget>[
          Expanded(child: _Header(l.shoppingDoneHeader(done.length))),
          TextButton.icon(icon: const Icon(Icons.delete_sweep_outlined), label: Text(l.shoppingClearDone), onPressed: onClearDone),
        ]),
        for (final i in done) tile(i),
      ],
    ]);
  }
}

Widget? _noCounter(BuildContext _, {required int currentLength, required bool isFocused, required int? maxLength}) => null;

class _GroupTextField extends StatelessWidget {
  const _GroupTextField({
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.onSubmitted,
    this.buildCounter,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final ValueChanged<String> onSubmitted;
  final InputCounterWidgetBuilder? buildCounter;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: ShoppingItem.maxGroup,
        inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(ShoppingItem.maxGroup, LengthMeasure.codePoints)],
        // Ohne eigenen Zähler (Eingabezeile: keiner) zählt er wie die Prüfung (#221).
        buildCounter: buildCounter ?? measuredCounter(controller, ShoppingItem.maxGroup, LengthMeasure.codePoints),
        enableIMEPersonalizedLearning: false,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: decoration,
        // Enter nimmt immer den getippten Text, nie einen Vorschlag.
        onSubmitted: onSubmitted,
      );
}

/// Vorhandene Gruppen zum Übernehmen ins Feld; ein Tipp fügt nichts hinzu.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.names, required this.controller, required this.focusNode});
  final List<String> names;
  final TextEditingController controller;
  final FocusNode focusNode;

  void _pick(String name) {
    controller.value = TextEditingValue(text: name, selection: TextSelection.collapsed(offset: name.length));
    // Der Chip kann nach der Übernahme verschwinden.
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final shown = groupSuggestions(names, value.text).take(maxGroupChips);
        if (shown.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(spacing: 6, children: <Widget>[
            for (final name in shown)
              Semantics(
                container: true,
                button: true,
                label: l.shoppingUseGroup(name),
                onTap: () => _pick(name),
                excludeSemantics: true,
                child: ActionChip(
                  label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () => _pick(name),
                ),
              ),
          ]),
        );
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
      );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.by, required this.byMe, required this.onToggle, required this.onEdit, required this.onDelete});
  final ShoppingItem item;
  final String by;

  /// Eigene Änderung: „zuletzt von dir“ (Dativ), nicht „von Du“ (#329).
  final bool byMe;
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
              Text(byMe ? l.shoppingLastByYou : l.shoppingLastBy(by), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
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
  const _EditDialog({required this.item, required this.groupNames});
  final ShoppingItem item;
  final List<String> groupNames;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.item.title);
  late final TextEditingController _qty = TextEditingController(text: widget.item.quantity);
  late final TextEditingController _group = TextEditingController(text: widget.item.group);
  final FocusNode _groupFocus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _qty.dispose();
    _group.dispose();
    _groupFocus.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, (title: _title.text, quantity: _qty.text, group: _group.text));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.shoppingEditTitle),
      scrollable: true,
      // Feste Wunschbreite: Sonst hinge sie von den Chips ab; kleine Geräte begrenzt der Dialog selbst.
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: ShoppingItem.maxTitle,
            inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(ShoppingItem.maxTitle, LengthMeasure.codePoints)],
            buildCounter: measuredCounter(_title, ShoppingItem.maxTitle, LengthMeasure.codePoints),
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: l.shoppingHintItem),
            // Desktop: Enter speichert (#68); mobil springt „Weiter“ zur Menge.
            textInputAction: TextInputAction.next,
            onSubmitted: PlatformInfo.enterSubmits ? (_) => _save() : null,
          ),
          TextField(
            controller: _qty,
            maxLength: ShoppingItem.maxQuantity,
            inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(ShoppingItem.maxQuantity, LengthMeasure.codePoints)],
            buildCounter: measuredCounter(_qty, ShoppingItem.maxQuantity, LengthMeasure.codePoints),
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: l.shoppingHintQuantity),
            textInputAction: TextInputAction.next,
            onSubmitted: PlatformInfo.enterSubmits ? (_) => _save() : null,
          ),
          _GroupTextField(
            controller: _group,
            focusNode: _groupFocus,
            decoration: InputDecoration(labelText: l.shoppingHintGroup),
            onSubmitted: (_) => _save(),
          ),
          TextFieldTapRegion(child: _GroupChips(names: widget.groupNames, controller: _group, focusNode: _groupFocus)),
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
