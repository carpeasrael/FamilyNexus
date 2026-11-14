part of '../event_editor_screen.dart';

/// Eine Zeile „Beginn“ oder „Ende“: Datum und, falls nicht ganztägig, Uhrzeit.
/// Bei großer Systemschrift steht die Beschriftung über der Zeile, damit sie nicht im Wort umbricht.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date, required this.time, required this.onDate, required this.onTime});
  final String label;
  final String date;
  final String? time;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;
    final buttons = <Widget>[
      Expanded(child: OutlinedButton(onPressed: onDate, child: Text(date))),
      if (time != null) ...<Widget>[
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onTime, child: Text(time!)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: large
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label), Row(children: buttons)])
          : Row(children: <Widget>[SizedBox(width: 64, child: Text(label)), ...buttons]),
    );
  }
}
