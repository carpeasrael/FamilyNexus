import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'cash_book_controller.dart';
import 'cash_book_screen.dart';
import 'cash_format.dart';

/// Liste der Kassenbücher mit Einladungen (#311, E-113). Einladungen werden **nie automatisch** angenommen: erst auf
/// „Annehmen“ und nach Bestätigung des Datenschutz-Hinweises.
class CashBooksScreen extends StatelessWidget {
  const CashBooksScreen({super.key, required this.controller});

  final CashBookController controller;

  Future<void> _run(BuildContext context, Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<void> _newBook(BuildContext context) async {
    final locale = Localizations.localeOf(context).toString();
    final result = await showDialog<({String title, String currency})>(context: context, builder: (_) => _NewBookDialog(locale: locale));
    if (result == null || !context.mounted) return;
    await _run(context, () async {
      await controller.createBook(title: result.title, currency: result.currency);
    });
  }

  Future<void> _accept(BuildContext context, String roomId) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.cashAcceptConfirmTitle),
        content: Text(l.cashAcceptConfirmBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashAccept)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () => controller.acceptInvitation(roomId));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(title: Text(l.cashTitle)),
      floatingActionButton: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => controller.available
            ? FloatingActionButton(heroTag: 'fab-cash-books', tooltip: l.cashNewBook, onPressed: () => _newBook(context), child: const Icon(Icons.add))
            : const SizedBox.shrink(),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (!controller.available) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.cashBookGone)));
          final books = controller.books;
          final invitations = controller.invitations;
          if (books.isEmpty && invitations.isEmpty) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.cashBooksEmpty, textAlign: TextAlign.center)));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: <Widget>[
            if (invitations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Semantics(header: true, child: Text(l.cashInvitationsTitle, style: Theme.of(context).textTheme.titleLarge)),
                    for (final i in invitations)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          Text(l.cashInvitationText(i.inviterName.isEmpty ? i.inviterId : i.inviterName)),
                          Wrap(spacing: 8, children: <Widget>[
                            TextButton(onPressed: () => _run(context, () => controller.declineInvitation(i.roomId)), child: Text(l.cashDecline)),
                            FilledButton(onPressed: () => _accept(context, i.roomId), child: Text(l.cashAccept)),
                          ]),
                        ]),
                      ),
                  ]),
                ),
              ),
            for (final b in books)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashBookScreen(controller: controller, roomId: b.roomId))),
                  semanticLabel: '${b.meta.title}, ${CashFormat.money(locale, b.monthTotalCents, b.meta.currency)}',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(b.meta.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(CashFormat.money(locale, b.monthTotalCents, b.meta.currency)),
                    Text(b.mine ? l.cashBookMine : l.cashBookBy(controller.nameOf(b.meta.owner)), style: Theme.of(context).textTheme.bodySmall),
                    if (b.isPlaceholder) Text(l.cashBookPlaceholder, style: Theme.of(context).textTheme.bodySmall),
                    if (!b.complete) Semantics(liveRegion: true, child: Text(l.cashIncomplete, style: Theme.of(context).textTheme.bodySmall)),
                    if (b.blocked) Semantics(liveRegion: true, child: Text(l.cashBlocked, style: Theme.of(context).textTheme.bodySmall)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _NewBookDialog extends StatefulWidget {
  const _NewBookDialog({required this.locale});
  final String locale;

  @override
  State<_NewBookDialog> createState() => _NewBookDialogState();
}

class _NewBookDialogState extends State<_NewBookDialog> {
  final TextEditingController _title = TextEditingController();
  late String _currency = CashFormat.localeCurrency(widget.locale);
  bool _showError = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final choices = CashFormat.choices(widget.locale);
    if (!choices.contains(_currency)) _currency = choices.first;
    return AlertDialog(
      title: Text(l.cashNewBook),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 60,
            decoration: InputDecoration(labelText: l.cashNewBookTitleHint, errorText: _showError && _title.text.trim().isEmpty ? l.cashErrInvalid : null),
          ),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: InputDecoration(labelText: l.cashNewBookCurrency),
            items: <DropdownMenuItem<String>>[for (final c in choices) DropdownMenuItem<String>(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ),
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) {
              setState(() => _showError = true);
              return;
            }
            Navigator.pop(context, (title: _title.text.trim(), currency: _currency));
          },
          child: Text(l.cashCreate),
        ),
      ],
    );
  }
}
