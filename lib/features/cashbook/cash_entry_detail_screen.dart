import 'package:flutter/material.dart';

import '../../domain/cash_book.dart';
import '../../l10n/gen/app_localizations.dart';
import 'cash_book_controller.dart';
import 'cash_format.dart';
import 'cash_receipt_picture.dart';

/// Ein fremder Eintrag, nur zum Lesen, mit dem Bon (#311, E-113).
class CashEntryDetailScreen extends StatelessWidget {
  const CashEntryDetailScreen({super.key, required this.controller, required this.roomId, required this.entry});

  final CashBookController controller;
  final String roomId;
  final CashEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    CashBookView? view;
    for (final b in controller.books) {
      if (b.roomId == roomId) view = b;
    }
    final currency = view?.meta.currency ?? 'EUR';
    return Scaffold(
      appBar: AppBar(title: Text(entry.store)),
      body: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        Text(CashFormat.money(locale, entry.amountCents, currency), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('${CashFormat.date(locale, entry.date)} · ${l.cashEntryBy(controller.nameOf(entry.author))}'),
        if (entry.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(entry.note)),
        if (entry.receipt != null) ...<Widget>[
          const SizedBox(height: 16),
          Semantics(header: true, child: Text(l.cashReceipt, style: Theme.of(context).textTheme.titleMedium)),
          CashReceiptPicture(controller: controller, roomId: roomId, entry: entry),
        ],
      ]),
    );
  }
}
