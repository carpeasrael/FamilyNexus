import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/anniversaries.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/length_limit.dart';

/// Fehler der Eingabeprüfung im Dialog (E-104); gleiche Regeln wie `AnniversaryService`.
enum AnniversaryFormError { nameEmpty, needDate, dateInvalid, dateFuture, deathBeforeBirth }

/// Eingabeprüfung des Dialogs als reine Funktion (testbar). Die Zukunftsprüfung gilt nur für **geänderte**
/// Felder: ein empfangener Eintrag mit Zukunftsjahr (bis 2100) lässt sich umbenennen.
class AnniversaryForm {
  const AnniversaryForm._();

  /// Alle drei Felder leer = kein Datum; Tag und Monat sind Pflicht, das Jahr ist optional.
  static ({AnniversaryDate? date, bool invalid}) parseDate(String day, String month, String year) {
    final d = day.trim();
    final m = month.trim();
    final y = year.trim();
    if (d.isEmpty && m.isEmpty && y.isEmpty) return (date: null, invalid: false);
    final di = int.tryParse(d);
    final mi = int.tryParse(m);
    final yi = y.isEmpty ? null : int.tryParse(y);
    if (di == null || mi == null || (y.isNotEmpty && yi == null)) return (date: null, invalid: true);
    final date = AnniversaryDate(month: mi, day: di, year: yi);
    return date.isValid ? (date: date, invalid: false) : (date: null, invalid: true);
  }

  static AnniversaryFormError? check({
    required String name,
    required ({AnniversaryDate? date, bool invalid}) birth,
    required ({AnniversaryDate? date, bool invalid}) death,
    required DateTime today,
    AnniversaryPerson? existing,
  }) {
    if (name.trim().isEmpty) return AnniversaryFormError.nameEmpty;
    if (birth.invalid || death.invalid) return AnniversaryFormError.dateInvalid;
    final b = birth.date;
    final d = death.date;
    if (b == null && d == null) return AnniversaryFormError.needDate;
    final t = DateTime.utc(today.year, today.month, today.day);
    if (b != null && b != existing?.birth && b.isAfter(t)) return AnniversaryFormError.dateFuture;
    if (d != null && d != existing?.death && d.isAfter(t)) return AnniversaryFormError.dateFuture;
    if (b != null && d != null && b.year != null && d.year != null) {
      if (d.year! < b.year! || (d.year == b.year && (d.month < b.month || (d.month == b.month && d.day < b.day)))) {
        return AnniversaryFormError.deathBeforeBirth;
      }
    }
    return null;
  }
}

/// Ergebnis des Dialogs: speichern oder löschen.
class AnniversaryFormResult {
  const AnniversaryFormResult({this.name = '', this.birth, this.death, this.delete = false});
  final String name;
  final AnniversaryDate? birth;
  final AnniversaryDate? death;
  final bool delete;
}

Future<AnniversaryFormResult?> showAnniversaryDialog(BuildContext context, {required DateTime today, AnniversaryPerson? existing}) =>
    showDialog<AnniversaryFormResult>(context: context, builder: (_) => _AnniversaryDialog(today: today, existing: existing));

class _AnniversaryDialog extends StatefulWidget {
  const _AnniversaryDialog({required this.today, this.existing});
  final DateTime today;
  final AnniversaryPerson? existing;

  @override
  State<_AnniversaryDialog> createState() => _AnniversaryDialogState();
}

class _AnniversaryDialogState extends State<_AnniversaryDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final List<TextEditingController> _birth = _controllers(widget.existing?.birth);
  late final List<TextEditingController> _death = _controllers(widget.existing?.death);
  AnniversaryFormError? _error;

  static List<TextEditingController> _controllers(AnniversaryDate? d) => <TextEditingController>[
        TextEditingController(text: d == null ? '' : '${d.day}'),
        TextEditingController(text: d == null ? '' : '${d.month}'),
        TextEditingController(text: d?.year == null ? '' : '${d!.year}'),
      ];

  @override
  void dispose() {
    _name.dispose();
    for (final c in <TextEditingController>[..._birth, ..._death]) {
      c.dispose();
    }
    super.dispose();
  }

  ({AnniversaryDate? date, bool invalid}) _parse(List<TextEditingController> c) => AnniversaryForm.parseDate(c[0].text, c[1].text, c[2].text);

  void _confirm() {
    final birth = _parse(_birth);
    final death = _parse(_death);
    final error = AnniversaryForm.check(name: _name.text, birth: birth, death: death, today: widget.today, existing: widget.existing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, AnniversaryFormResult(name: _name.text.trim(), birth: birth.date, death: death.date));
  }

  String _errorText(AppLocalizations l, AnniversaryFormError e) => switch (e) {
        AnniversaryFormError.nameEmpty => l.anniversaryNameEmpty,
        AnniversaryFormError.needDate => l.anniversaryNeedDate,
        AnniversaryFormError.dateInvalid => l.anniversaryDateInvalid,
        AnniversaryFormError.dateFuture => l.anniversaryDateFuture,
        AnniversaryFormError.deathBeforeBirth => l.anniversaryDeathBeforeBirth,
      };

  Widget _dateRow(AppLocalizations l, String title, List<TextEditingController> c, {required bool last}) {
    Widget field(TextEditingController ctl, String label, int maxLen) => TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLen)],
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: label),
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onChanged: (_) => setState(() => _error = null),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      Row(children: <Widget>[
        Expanded(child: field(c[0], l.anniversaryDay, 2)),
        const SizedBox(width: 8),
        Expanded(child: field(c[1], l.anniversaryMonth, 2)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: field(c[2], l.anniversaryYear, 4)),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final error = _error;
    return AlertDialog(
      title: Text(widget.existing == null ? l.anniversaryAdd : l.anniversaryEdit),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: AnniversaryPerson.maxName,
            inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(AnniversaryPerson.maxName, LengthMeasure.codePoints)],
            buildCounter: measuredCounter(_name, AnniversaryPerson.maxName, LengthMeasure.codePoints),
            textCapitalization: TextCapitalization.words,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: l.anniversaryName),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
          ),
          _dateRow(l, l.anniversaryBirth, _birth, last: false),
          _dateRow(l, l.anniversaryDeath, _death, last: true),
          const SizedBox(height: 8),
          Text(l.anniversaryDatesHint, style: Theme.of(context).textTheme.bodySmall),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(_errorText(l, error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
        ]),
      ),
      actions: <Widget>[
        if (widget.existing != null)
          TextButton(onPressed: () => Navigator.pop(context, const AnniversaryFormResult(delete: true)), child: Text(l.delete)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _confirm, child: Text(l.save)),
      ],
    );
  }
}
