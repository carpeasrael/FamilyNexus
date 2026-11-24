import 'package:flutter/material.dart';

import '../../domain/cash_book.dart';
import '../../domain/cash_month.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'cash_book_controller.dart';
import 'cash_book_members_screen.dart';
import 'cash_entry_detail_screen.dart';
import 'cash_entry_editor_screen.dart';
import 'cash_format.dart';

/// Ein Kassenbuch: Monatswahl, Summe, Einträge (#311, E-113). Verschwindet das Buch (Familienwechsel, Entfernen), zeigt
/// die Seite einen Hinweis statt abzustürzen.
class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key, required this.controller, required this.roomId});

  final CashBookController controller;
  final String roomId;

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  late CashMonth _month = widget.controller.books.where((b) => b.roomId == widget.roomId).firstOrNull?.month ?? CashMonth.of(DateTime.now());
  Future<List<CashEntry>>? _entries;

  CashBookController get _c => widget.controller;

  CashBookView? get _view {
    for (final b in _c.books) {
      if (b.roomId == widget.roomId) return b;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_reload);
    _entries = _c.entriesOf(widget.roomId, _month);
  }

  @override
  void dispose() {
    _c.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final f = _c.entriesOf(widget.roomId, _month);
    setState(() {
      _entries = f;
    });
  }

  void _go(CashMonth m) {
    _month = m;
    _reload();
  }

  Future<void> _leave(CashBookView v) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.cashLeave),
        content: Text(l.cashLeaveConfirm),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashLeave)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _c.leaveBook(v);
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final v = _view;
    if (v == null || !_c.available) {
      return Scaffold(
        appBar: AppBar(title: Text(l.cashTitle)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Semantics(liveRegion: true, child: Text(l.cashBookGone)))),
      );
    }
    final currency = v.meta.currency;
    return Scaffold(
      appBar: AppBar(
        title: Text(v.meta.title),
        actions: <Widget>[
          IconButton(
            tooltip: l.cashMembersTitle,
            icon: const Icon(Icons.group_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashBookMembersScreen(controller: _c, roomId: widget.roomId))),
          ),
          if (_c.canLeave(v))
            PopupMenuButton<String>(
              onSelected: (_) => _leave(v),
              itemBuilder: (_) => <PopupMenuEntry<String>>[PopupMenuItem<String>(value: 'leave', child: Text(l.cashLeave))],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-cash-book',
        tooltip: l.cashAddEntry,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashEntryEditorScreen(controller: _c, roomId: widget.roomId))),
        child: const Icon(Icons.add),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: <Widget>[
        if (!v.complete) _Notice(text: l.cashIncomplete, icon: Icons.history_toggle_off),
        if (v.blocked) _Notice(text: l.cashBlocked, icon: Icons.lock_outline),
        if (v.pendingOwn > 0) _Notice(text: l.cashPending(v.pendingOwn), icon: Icons.schedule_send_outlined),
        Row(children: <Widget>[
          IconButton(tooltip: l.cashMonthPrev, icon: const Icon(Icons.chevron_left), onPressed: () => _go(_month.previous)),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(CashFormat.month(locale, DateTime(_month.year, _month.month)), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          IconButton(tooltip: l.cashMonthNext, icon: const Icon(Icons.chevron_right), onPressed: () => _go(_month.next)),
        ]),
        FutureBuilder<List<CashEntry>>(
          future: _entries,
          builder: (context, snap) {
            final entries = snap.data;
            if (entries == null) return const SizedBox.shrink();
            final total = entries.fold<int>(0, (a, e) => a + e.amountCents);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.cashMonthTotal(CashFormat.money(locale, total, currency)), style: Theme.of(context).textTheme.headlineSmall),
              ),
              if (entries.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.cashNoEntries)),
              for (final e in entries) _EntryTile(entry: e, controller: _c, roomId: widget.roomId, locale: locale, currency: currency),
            ]);
          },
        ),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          child: Row(children: <Widget>[
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Semantics(liveRegion: true, child: Text(text))),
          ]),
        ),
      );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.controller, required this.roomId, required this.locale, required this.currency});
  final CashEntry entry;
  final CashBookController controller;
  final String roomId;
  final String locale;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mine = entry.author == controller.me;
    final who = mine ? l.cashEntryByMe : l.cashEntryBy(controller.nameOf(entry.author));
    final amount = CashFormat.money(locale, entry.amountCents, currency);
    final date = CashFormat.date(locale, entry.date);
    return Semantics(
      label: l.cashEntrySemantics(entry.store, amount, date),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(entry.receipt != null ? Icons.receipt_long_outlined : Icons.shopping_bag_outlined),
        title: Text(entry.store),
        subtitle: Text(<String>[date, who, if (entry.note.isNotEmpty) entry.note].join(' · ')),
        trailing: Text(amount, style: Theme.of(context).textTheme.titleMedium),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => mine
              ? CashEntryEditorScreen(controller: controller, roomId: roomId, entry: entry)
              : CashEntryDetailScreen(controller: controller, roomId: roomId, entry: entry),
        )),
      ),
    );
  }
}
