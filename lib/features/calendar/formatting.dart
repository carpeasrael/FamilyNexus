import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/calendar_event.dart';
import '../../domain/occurrence.dart';
import '../../l10n/gen/app_localizations.dart';

/// Uhrzeit [hour]:[minute] im Format des Geräts (12/24 Stunden) und der App-Sprache – die eine Stelle für
/// alle angezeigten Uhrzeiten (#162). Rechnet nicht um: die Zone wählt der Aufrufer.
String formatClock(BuildContext context, int hour, int minute) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final f = MediaQuery.alwaysUse24HourFormatOf(context) ? DateFormat.Hm(locale) : DateFormat.jm(locale);
  return f.format(DateTime(2000, 1, 1, hour, minute));
}

/// Formatierung von Terminzeiten in der Zeitzone des Betrachters.
class Fmt {
  Fmt(this.context, this.zone)
      : locale = Localizations.localeOf(context).toLanguageTag(),
        use24h = MediaQuery.alwaysUse24HourFormatOf(context);

  final BuildContext context;
  final tz.Location zone;
  final String locale;
  final bool use24h;

  tz.TZDateTime local(DateTime utc) => tz.TZDateTime.from(utc, zone);

  String time(DateTime utc) {
    final t = local(utc);
    return formatClock(context, t.hour, t.minute);
  }

  String dateLong(DateTime d) => DateFormat.yMMMMEEEEd(locale).format(d);
  String dateShort(DateTime d) => DateFormat.yMMMd(locale).format(d);
  String weekday(DateTime d) => DateFormat.E(locale).format(d);
  String monthYear(DateTime d) => DateFormat.yMMMM(locale).format(d);
  String dayMonth(DateTime d) => DateFormat.MMMd(locale).format(d);

  /// „09:00 – 10:00“ bzw. „Ganztägig“ für den Tag [day] (lokal).
  String range(Occurrence o, AppLocalizations l, {DateTime? day}) {
    if (o.event.allDay) return l.calendarAllDay;
    final s = local(o.start);
    final e = local(o.end);
    final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
    if (sameDay) return '${time(o.start)} – ${time(o.end)}';
    return '${dateShort(s)} ${time(o.start)} – ${dateShort(e)} ${time(o.end)}';
  }

  String eventSpan(CalendarEvent e, AppLocalizations l) {
    if (e.allDay) {
      final s = DateTime.utc(e.start.year, e.start.month, e.start.day);
      final en = DateTime.utc(e.end.year, e.end.month, e.end.day);
      return s == en ? dateLong(s) : '${dateShort(s)} – ${dateShort(en)}';
    }
    final s = local(e.start);
    final en = local(e.end);
    final sameDay = s.year == en.year && s.month == en.month && s.day == en.day;
    return sameDay
        ? '${dateLong(s)}, ${time(e.start)} – ${time(e.end)}'
        : '${dateShort(s)} ${time(e.start)} – ${dateShort(en)} ${time(e.end)}';
  }
}
