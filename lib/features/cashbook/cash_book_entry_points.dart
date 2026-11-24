import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../calendar/calendar_screen.dart' show SectionCard;
import 'cash_book_controller.dart';
import 'cash_books_screen.dart';
import 'cash_format.dart';

void openCashBooks(BuildContext context, CashBookController controller) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashBooksScreen(controller: controller)));

/// Karte „Kassenbuch“ auf „Heute“ (#311, E-113): je Buch (höchstens drei) die Summe des laufenden Monats in der Währung
/// des Buchs, nie über Währungen addiert. Nur freigeschaltet und für Moderatoren; sonst gibt es keine Karte.
class CashBookTodayCard extends StatelessWidget {
  const CashBookTodayCard({super.key, required this.controller});

  final CashBookController controller;

  static const int maxBooks = 3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.available) return const SizedBox.shrink();
        final books = controller.books.take(maxBooks).toList();
        return SectionCard(
          title: l.cashTodayTitle,
          trailing: TextButton(onPressed: () => openCashBooks(context, controller), child: Text(l.cashOpen)),
          child: books.isEmpty
              ? Text(l.cashTodayNone)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  for (final b in books) Text(l.cashTodayBook(b.meta.title, CashFormat.money(locale, b.monthTotalCents, b.meta.currency))),
                ]),
        );
      },
    );
  }
}

/// Eintrag „Kassenbuch“ in den Einstellungen (#311, E-113); nur freigeschaltet und für Moderatoren.
class CashBookSettingsTile extends StatelessWidget {
  const CashBookSettingsTile({super.key, required this.controller});

  final CashBookController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.available) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l.cashTitle),
              subtitle: Text(l.cashSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openCashBooks(context, controller),
            ),
          ),
        );
      },
    );
  }
}
