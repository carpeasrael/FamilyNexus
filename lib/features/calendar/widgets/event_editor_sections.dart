part of '../event_editor_screen.dart';

/// Titel, Ganztägig, Beginn und Ende, Zeitfehler und Zeitzone.
class _TitleTimeCard extends StatelessWidget {
  const _TitleTimeCard({
    required this.title,
    required this.allDay,
    required this.onAllDay,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.onStartDate,
    required this.onStartTime,
    required this.onEndDate,
    required this.onEndTime,
    required this.timeError,
    required this.zoneName,
  });
  final TextEditingController title;
  final bool allDay;
  final ValueChanged<bool> onAllDay;
  final String startDate;

  /// `null` bei ganztägigen Terminen.
  final String? startTime;
  final String endDate;
  final String? endTime;
  final VoidCallback onStartDate;
  final VoidCallback onStartTime;
  final VoidCallback onEndDate;
  final VoidCallback onEndTime;
  final String? timeError;
  final String zoneName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return GlassCard(
      child: Column(children: <Widget>[
        TextFormField(
          controller: title,
          maxLength: CalendarEvent.maxTitle,
          inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(CalendarEvent.maxTitle, LengthMeasure.utf16)],
          buildCounter: measuredCounter(title, CalendarEvent.maxTitle, LengthMeasure.utf16),
          textCapitalization: TextCapitalization.sentences,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.eventTitle),
          validator: (v) => (v == null || v.trim().isEmpty) ? l.eventTitleRequired : null,
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.eventAllDay), value: allDay, onChanged: onAllDay),
        _DateRow(label: l.eventStart, date: startDate, time: startTime, onDate: onStartDate, onTime: onStartTime),
        _DateRow(label: l.eventEnd, date: endDate, time: endTime, onDate: onEndDate, onTime: onEndTime),
        if (timeError != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(liveRegion: true, child: Text(timeError!, style: TextStyle(color: t.danger))),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l.eventTimeZone(zoneName), style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }
}

/// Eine Zeile „Beginn“ oder „Ende“: Datum und, falls nicht ganztägig, Uhrzeit.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date, required this.time, required this.onDate, required this.onTime});
  final String label;
  final String date;
  final String? time;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: <Widget>[
        SizedBox(width: 64, child: Text(label)),
        Expanded(child: OutlinedButton(onPressed: onDate, child: Text(date))),
        if (time != null) ...<Widget>[
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onTime, child: Text(time!)),
        ],
      ]),
    );
  }
}

/// Sichtbarkeit: privat oder mit der Familie geteilt.
class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({required this.visibility, required this.showChangeNote, required this.onChanged});
  final EventVisibility visibility;

  /// Ein geteilter Termin wird privat gestellt: Hinweis, dass die Familie ihn behält.
  final bool showChangeNote;
  final ValueChanged<EventVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventVisibility, style: Theme.of(context).textTheme.titleSmall),
        SegmentedButton<EventVisibility>(
          segments: <ButtonSegment<EventVisibility>>[
            ButtonSegment<EventVisibility>(value: EventVisibility.private, icon: const Icon(Icons.lock_outline), label: Text(l.visibilityPrivate)),
            ButtonSegment<EventVisibility>(value: EventVisibility.shared, icon: const Icon(Icons.groups_outlined), label: Text(l.visibilityShared)),
          ],
          selected: <EventVisibility>{visibility},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 8),
        Text(visibility == EventVisibility.shared ? l.visibilitySharedHint : l.visibilityPrivateHint, style: Theme.of(context).textTheme.bodySmall),
        if (showChangeNote)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.visibilityChangeNote, style: TextStyle(color: t.warning))),
      ]),
    );
  }
}

/// Ort und Notiz.
class _PlaceNoteCard extends StatelessWidget {
  const _PlaceNoteCard({required this.location, required this.note});
  final TextEditingController location;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Column(children: <Widget>[
        TextFormField(
          controller: location,
          maxLength: CalendarEvent.maxLocation,
          inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(CalendarEvent.maxLocation, LengthMeasure.utf16)],
          buildCounter: measuredCounter(location, CalendarEvent.maxLocation, LengthMeasure.utf16),
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.eventLocation),
        ),
        TextFormField(
          controller: note,
          maxLength: CalendarEvent.maxNote,
          inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(CalendarEvent.maxNote, LengthMeasure.utf16)],
          buildCounter: measuredCounter(note, CalendarEvent.maxNote, LengthMeasure.utf16),
          maxLines: 4,
          minLines: 2,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.eventNote),
        ),
      ]),
    );
  }
}

/// Wiederholung: Häufigkeit, Abstand, Wochentage, Ende.
class _RepeatCard extends StatelessWidget {
  const _RepeatCard({
    required this.frequency,
    required this.interval,
    required this.weekdays,
    required this.end,
    required this.untilLabel,
    required this.count,
    required this.onFrequency,
    required this.onWeekday,
    required this.onEnd,
    required this.onPickUntil,
  });
  final Frequency frequency;
  final TextEditingController interval;
  final Set<int> weekdays;
  final _End end;

  /// Beschriftung der Schaltfläche „Am Datum“ (mit gewähltem Datum, falls gesetzt).
  final String untilLabel;
  final TextEditingController count;
  final ValueChanged<Frequency> onFrequency;
  final void Function(int day, bool on) onWeekday;
  final ValueChanged<_End> onEnd;
  final VoidCallback onPickUntil;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = <Frequency, String>{
      Frequency.none: l.repeatNone,
      Frequency.daily: l.repeatDaily,
      Frequency.weekly: l.repeatWeekly,
      Frequency.monthly: l.repeatMonthly,
      Frequency.yearly: l.repeatYearly,
    };
    final weekdayNames = <String>[l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu, l.weekdayFri, l.weekdaySat, l.weekdaySun];
    final unit = switch (frequency) {
      Frequency.daily => l.repeatUnitDays,
      Frequency.weekly => l.repeatUnitWeeks,
      Frequency.monthly => l.repeatUnitMonths,
      Frequency.yearly => l.repeatUnitYears,
      Frequency.none => '',
    };
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventRepeat, style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, children: <Widget>[
          for (final e in labels.entries)
            ChoiceChip(label: Text(e.value), selected: frequency == e.key, onSelected: (_) => onFrequency(e.key)),
        ]),
        if (frequency != Frequency.none) ...<Widget>[
          const SizedBox(height: 8),
          Row(children: <Widget>[
            Text(l.repeatEvery),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: TextFormField(
                controller: interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 1 || n > Recurrence.maxInterval) ? l.errInvalidInput : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Text(unit),
          ]),
          if (frequency == Frequency.weekly)
            Wrap(spacing: 6, children: <Widget>[
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(weekdayNames[i]),
                  selected: weekdays.contains(i + 1),
                  onSelected: (v) => onWeekday(i + 1, v),
                ),
            ]),
          const SizedBox(height: 8),
          Text(l.repeatEnds, style: Theme.of(context).textTheme.labelMedium),
          Wrap(spacing: 8, children: <Widget>[
            ChoiceChip(label: Text(l.repeatEndsNever), selected: end == _End.never, onSelected: (_) => onEnd(_End.never)),
            ChoiceChip(label: Text(l.repeatEndsOn), selected: end == _End.until, onSelected: (_) => onEnd(_End.until)),
            ChoiceChip(label: Text(l.repeatEndsAfter), selected: end == _End.count, onSelected: (_) => onEnd(_End.count)),
          ]),
          if (end == _End.until)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(onPressed: onPickUntil, child: Text(untilLabel)),
            ),
          if (end == _End.count)
            SizedBox(
              width: 140,
              child: TextFormField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.repeatCount),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 1 || n > Recurrence.maxCount) ? l.errInvalidInput : null;
                },
              ),
            ),
        ],
      ]),
    );
  }
}

/// Teilnehmer eines geteilten Termins.
class _AttendeesCard extends StatelessWidget {
  const _AttendeesCard({required this.members, required this.selected, required this.onToggle});
  final List<FamilyMember> members;
  final Set<String> selected;
  final void Function(String userId, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventAttendees, style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, children: <Widget>[
          for (final m in members)
            FilterChip(
              label: Text(m.displayName),
              selected: selected.contains(m.userId),
              onSelected: (v) => onToggle(m.userId, v),
            ),
        ]),
      ]),
    );
  }
}

/// Thema eines geteilten Termins (E-99): Chips mit Farbpunkt und Name, plus „Ohne Thema“. Nur Moderatoren legen
/// Themen an; jedes Mitglied wählt eines für den eigenen Termin.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.controller, required this.selected, required this.onSelect});
  final CalendarController controller;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final themes = controller.eventThemes;
    // Ein unbekanntes oder gelöschtes Thema gilt als „Ohne Thema“ (die gespeicherte ID bleibt unberührt).
    final current = controller.themeOf(selected)?.id;
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventTheme, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
          ChoiceChip(
            label: Text(l.eventThemeNone),
            selected: current == null,
            onSelected: (_) => onSelect(null),
          ),
          for (final th in themes)
            ChoiceChip(
              avatar: PersonDot(colorIndex: th.colorIndex),
              label: Text(th.name),
              selected: current == th.id,
              onSelected: (_) => onSelect(th.id),
            ),
        ]),
      ]),
    );
  }
}

/// Privat: Die Farbe ist fest Himmelblau, es gibt keine Auswahl (E-99).
class _PrivateColorHint extends StatelessWidget {
  const _PrivateColorHint();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Row(children: <Widget>[
        const PersonDot(colorIndex: EventTheme.privateColorIndex),
        const SizedBox(width: 10),
        Expanded(child: Text(l.eventThemePrivateHint)),
      ]),
    );
  }
}

/// Erinnerungen (Minuten vor Beginn).
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.selected, required this.onToggle});
  final Set<int> selected;
  final void Function(int minutes, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.remindersTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
          for (final m in kReminderChoices)
            FilterChip(
              label: Text(m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m))),
              selected: selected.contains(m),
              onSelected: (v) => onToggle(m, v),
            ),
        ]),
        const SizedBox(height: 6),
        Text(l.remindersHint, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

/// Fehlerzeile unter dem Formular (Screenreader liest sie vor).
class _FormError extends StatelessWidget {
  const _FormError({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AuroraTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(liveRegion: true, child: Text(text, style: TextStyle(color: t.danger))),
    );
  }
}
