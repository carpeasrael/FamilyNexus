part of '../tasks_screen.dart';

/// Beschreibung der Liste in einer Karte mit Infosymbol.
class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AuroraTokens.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(Icons.info_outline, size: 18, color: t.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

/// Ein Punkt der Liste: Kontrollkästchen (nur die zugewiesene Person), Titel, Erledigt-Zeile und Kommentar.
class _TaskItemRow extends StatelessWidget {
  const _TaskItemRow({
    required this.item,
    required this.entry,
    required this.list,
    required this.canComplete,
    required this.onComplete,
    required this.onUndo,
  });
  final TaskItem item;

  /// Eintrag der Erledigung im laufenden Zeitraum; `null`, wenn offen.
  final TaskLogEntry? entry;
  final TaskList list;
  final bool canComplete;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final e = entry;
    final isDone = e != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(children: <Widget>[
          Semantics(
            label: isDone ? l.tasksMarkUndone(item.title) : l.tasksMarkDone(item.title),
            child: Checkbox(
              value: isDone,
              onChanged: canComplete ? (v) => v == true ? onComplete() : onUndo() : null,
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(
                item.title,
                style: isDone
                    ? Theme.of(context).textTheme.bodyLarge?.copyWith(decoration: TextDecoration.lineThrough, color: t.textSecondary)
                    : Theme.of(context).textTheme.bodyLarge,
              ),
              if (e != null) ...<Widget>[
                Text(
                  l.tasksDoneOn(_date(context, e.doneOn), _time(context, list, e.at)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
                if (e.comment.isNotEmpty) Text(e.comment, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Eine Zeile des Verlaufs: erledigt oder zurückgenommen, wer, wann, Kommentar.
class _TaskHistoryTile extends StatelessWidget {
  const _TaskHistoryTile({required this.entry, required this.list, required this.by});
  final TaskLogEntry entry;
  final TaskList list;

  /// Name der Person, die den Eintrag gemacht hat (Satzform).
  final String by;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = entry;
    return ListTile(
      dense: true,
      leading: Icon(e.kind == TaskLogKind.done ? Icons.check_circle_outline : Icons.undo),
      title: Text(() {
        final title = list.items.where((i) => i.id == e.itemId).map((i) => i.title).firstOrNull ?? '';
        return e.kind == TaskLogKind.done ? l.tasksHistoryDone(title) : l.tasksHistoryUndone(title);
      }()),
      subtitle: Text([
        l.tasksHistoryLine(by, _date(context, e.doneOn), _time(context, list, e.at)),
        if (e.comment.isNotEmpty) e.comment,
      ].join('\n')),
    );
  }
}

/// Kommentar-Dialog beim Abhaken; die Eingabe gehört dem Dialog.
class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.title});
  final String title;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _comment,
        autofocus: true,
        maxLength: TaskLogEntry.maxComment,
        inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(TaskLogEntry.maxComment, LengthMeasure.codePoints)],
        buildCounter: measuredCounter(_comment, TaskLogEntry.maxComment, LengthMeasure.codePoints),
        enableIMEPersonalizedLearning: false,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.tasksCommentHint),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _comment.text), child: Text(l.tasksConfirmDone)),
      ],
    );
  }
}
