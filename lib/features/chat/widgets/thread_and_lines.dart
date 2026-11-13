part of '../chat_screen.dart';

/// Datumszeile vor der ersten Nachricht eines Tages (#254).
class _DayLine extends StatelessWidget {
  const _DayLine({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final label = switch (chatDayOf(day, DateTime.now())) {
      ChatDay.today => l.chatToday,
      ChatDay.yesterday => l.chatYesterday,
      ChatDay.other => DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(day),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Semantics(
          header: true,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textSecondary)),
        ),
      ),
    );
  }
}

/// Marke über der ersten ungelesenen Nachricht: Linie **und** Text, nicht nur Farbe (#254).
class _UnreadLine extends StatelessWidget {
  const _UnreadLine({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: <Widget>[
        Expanded(child: Divider(color: t.primary, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l.chatNewMessages,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.primary, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Divider(color: t.primary, thickness: 1)),
      ]),
    );
  }
}
