import 'anniversaries.dart';

/// Art des Tages.
enum AnniversaryKind { birth, death }

/// Ein Vorkommen eines Geburts- oder Todestags (E-104).
class AnniversaryHit {
  const AnniversaryHit({
    required this.person,
    required this.kind,
    required this.date,
    required this.occursOn,
    required this.daysUntil,
    this.yearsSince,
    this.ageAtNext,
  });

  final AnniversaryPerson person;
  final AnniversaryKind kind;
  final AnniversaryDate date;

  /// Wirksames Datum (UTC-Kalendertag).
  final DateTime occursOn;

  /// Tage von „heute“ bis [occursOn]; negativ für einen vergangenen Tag im Kalender.
  final int daysUntil;

  /// Vollendete Jahre seit dem Datum (heute), nur mit Jahr.
  final int? yearsSince;

  /// Jahre am Tag [occursOn] (`occursOn.year − Jahr`), nur mit Jahr.
  final int? ageAtNext;
}

enum AnniversaryLineKind { willBe, currentAge, isAge, wouldBe, nthDeathDay, yearsAgo }

/// Strukturierte Zusatzzeile der Anzeige; den Text bildet die Oberfläche über l10n.
class AnniversaryLine {
  const AnniversaryLine(this.kind, this.number);
  final AnniversaryLineKind kind;
  final int number;

  @override
  bool operator ==(Object other) => other is AnniversaryLine && other.kind == kind && other.number == number;

  @override
  int get hashCode => Object.hash(kind, number);

  @override
  String toString() => 'AnniversaryLine(${kind.name}, $number)';
}

/// Reine Rechenfunktionen der Geburts- und Gedenktage. „Heute“ ist ein Kalenderdatum (UTC-Tag) vom Aufrufer,
/// es gibt keinen Zeitzonen-Versatz.
class AnniversaryCalc {
  const AnniversaryCalc._();

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// 29.2.-Regel: das wirksame Datum im Jahr [year] ist der 29.2., in Nichtschaltjahren der 28.2.
  static DateTime effectiveDate(AnniversaryDate date, int year) {
    final day = date.month == 2 && date.day == 29 && !AnniversaryDate.isLeap(year) ? 28 : date.day;
    return DateTime.utc(year, date.month, day);
  }

  /// Frühestes wirksames Datum ≥ [today].
  static DateTime nextOccurrence(AnniversaryDate date, DateTime today) {
    final t = _day(today);
    final thisYear = effectiveDate(date, t.year);
    return thisYear.isBefore(t) ? effectiveDate(date, t.year + 1) : thisYear;
  }

  /// Vollendete Jahre seit dem Datum; `null` ohne Jahr.
  static int? yearsSince(AnniversaryDate date, DateTime today) {
    final y = date.year;
    if (y == null) return null;
    final t = _day(today);
    final n = t.year - y;
    return t.isBefore(effectiveDate(date, t.year)) ? n - 1 : n;
  }

  /// Jahre am nächsten Vorkommen; `null` ohne Jahr.
  static int? ageAtNext(AnniversaryDate date, DateTime today) {
    final y = date.year;
    return y == null ? null : nextOccurrence(date, today).year - y;
  }

  static int daysBetween(DateTime from, DateTime to) => _day(to).difference(_day(from)).inDays;

  static int daysUntil(AnniversaryDate date, DateTime today) => daysBetween(today, nextOccurrence(date, today));

  /// Geburts- und Todestage einer Person als Treffer ab [today] (je ein Treffer je vorhandenem Datum).
  static List<AnniversaryHit> hitsOf(AnniversaryPerson person, DateTime today) => <AnniversaryHit>[
        if (person.birth != null) _next(person, AnniversaryKind.birth, person.birth!, today),
        if (person.death != null) _next(person, AnniversaryKind.death, person.death!, today),
      ];

  static AnniversaryHit _next(AnniversaryPerson p, AnniversaryKind kind, AnniversaryDate date, DateTime today) {
    final next = nextOccurrence(date, today);
    return AnniversaryHit(
      person: p,
      kind: kind,
      date: date,
      occursOn: next,
      daysUntil: daysBetween(today, next),
      yearsSince: yearsSince(date, today),
      ageAtNext: date.year == null ? null : next.year - date.year!,
    );
  }

  static int _compare(AnniversaryHit a, AnniversaryHit b) {
    final byDay = a.occursOn.compareTo(b.occursOn);
    if (byDay != 0) return byDay;
    final byName = a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
    if (byName != 0) return byName;
    final byKind = a.kind.index.compareTo(b.kind.index);
    return byKind != 0 ? byKind : a.person.id.compareTo(b.person.id);
  }

  /// Alle nächsten Vorkommen, nach Datum sortiert.
  static List<AnniversaryHit> upcoming(Iterable<AnniversaryPerson> people, DateTime today) =>
      <AnniversaryHit>[for (final p in people) if (!p.deleted) ...hitsOf(p, today)]..sort(_compare);

  /// Treffer, deren nächstes Vorkommen in [0, leadDays] Tagen liegt.
  static List<AnniversaryHit> dueWithin(Iterable<AnniversaryPerson> people, DateTime today, int leadDays) =>
      <AnniversaryHit>[for (final h in upcoming(people, today)) if (h.daysUntil <= leadDays) h];

  /// Treffer mit wirksamem Datum im Bereich [from, to] (Kalendertage, einschließlich); auch vergangene Tage.
  static List<AnniversaryHit> between(Iterable<AnniversaryPerson> people, DateTime from, DateTime to, DateTime today) {
    final a = _day(from);
    final b = _day(to);
    final out = <AnniversaryHit>[];
    void add(AnniversaryPerson p, AnniversaryKind kind, AnniversaryDate date) {
      for (var y = a.year; y <= b.year; y++) {
        final eff = effectiveDate(date, y);
        if (eff.isBefore(a) || eff.isAfter(b)) continue;
        out.add(AnniversaryHit(
          person: p,
          kind: kind,
          date: date,
          occursOn: eff,
          daysUntil: daysBetween(today, eff),
          yearsSince: yearsSince(date, today),
          ageAtNext: date.year == null ? null : y - date.year!,
        ));
      }
    }

    for (final p in people) {
      if (p.deleted) continue;
      if (p.birth != null) add(p, AnniversaryKind.birth, p.birth!);
      if (p.death != null) add(p, AnniversaryKind.death, p.death!);
    }
    return out..sort(_compare);
  }

  /// Anzeigeregel für die Altersangaben (nur mit Jahr; unsinnige Werte unterdrücken genau die betroffene Zeile).
  /// Für `daysUntil <= 0` gilt die Spalte „heute“ (auch für vergangene Kalendertage).
  static List<AnniversaryLine> lines(AnniversaryHit hit, AnniversaryPerson person) {
    if (hit.date.year == null) return const <AnniversaryLine>[];
    final n = hit.ageAtNext;
    final k = hit.yearsSince;
    final future = hit.daysUntil > 0;
    final out = <AnniversaryLine>[];
    if (hit.kind == AnniversaryKind.birth) {
      if (person.death != null) {
        if (n != null && n >= 1) out.add(AnniversaryLine(AnniversaryLineKind.wouldBe, n));
      } else if (future) {
        if (n != null && n >= 1) out.add(AnniversaryLine(AnniversaryLineKind.willBe, n));
        if (k != null && k >= 0 && n != null && n >= 1) out.add(AnniversaryLine(AnniversaryLineKind.currentAge, k));
      } else if (n != null && n >= 1) {
        out.add(AnniversaryLine(AnniversaryLineKind.isAge, n));
      }
    } else {
      if (n != null && n >= 1) out.add(AnniversaryLine(AnniversaryLineKind.nthDeathDay, n));
      if (future && k != null && k >= 1 && n != null && n >= 1) out.add(AnniversaryLine(AnniversaryLineKind.yearsAgo, k));
    }
    return out;
  }
}

/// Kurzform von [AnniversaryCalc.lines].
List<AnniversaryLine> anniversaryLines(AnniversaryHit hit, AnniversaryPerson person) => AnniversaryCalc.lines(hit, person);
