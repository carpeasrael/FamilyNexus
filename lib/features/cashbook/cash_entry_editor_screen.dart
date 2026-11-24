import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/cash_book.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import 'cash_book_controller.dart';
import 'cash_format.dart';
import 'cash_receipt_picture.dart';

/// Eintrag anlegen oder (eigenen) ändern, mit Bon-Foto (#311, E-113). Speichern ist während der Aufbereitung und
/// Sendung gesperrt; ungespeicherte Änderungen werden beim Zurückgehen nie stillschweigend verworfen.
class CashEntryEditorScreen extends StatefulWidget {
  const CashEntryEditorScreen({super.key, required this.controller, required this.roomId, this.entry});

  final CashBookController controller;
  final String roomId;

  /// `null`: neuer Eintrag.
  final CashEntry? entry;

  @override
  State<CashEntryEditorScreen> createState() => _CashEntryEditorScreenState();
}

class _CashEntryEditorScreenState extends State<CashEntryEditorScreen> {
  final TextEditingController _store = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late DateTime _date;
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;
  bool _dirty = false;
  bool _submitted = false;
  bool _initialized = false;

  CashBookController get _c => widget.controller;
  bool get _gone => !_c.available || !_c.books.any((b) => b.roomId == widget.roomId);

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _date = e?.date ?? DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (e != null) {
      _store.text = e.store;
      _note.text = e.note;
    }
    _c.addListener(_onController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final e = widget.entry;
    if (e != null) _amount.text = CashFormat.amountText(Localizations.localeOf(context).toString(), e.amountCents);
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _store.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  bool get _hasPhoto => _newPhoto != null || (widget.entry?.receipt != null && !_removePhoto);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(CashBookLimits.minDate) ? CashBookLimits.minDate : (_date.isAfter(CashBookLimits.maxDate) ? CashBookLimits.maxDate : _date),
      firstDate: CashBookLimits.minDate,
      lastDate: CashBookLimits.maxDate,
    );
    if (picked != null) {
      setState(() {
        _date = DateTime.utc(picked.year, picked.month, picked.day);
        _dirty = true;
      });
    }
  }

  Future<void> _choosePhoto() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.cashReceiptPrivacyTitle),
        content: Text(l.cashReceiptPrivacyBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashReceiptContinue)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _c.pickPhoto();
      if (bytes == null || !mounted) return;
      setState(() {
        _newPhoto = bytes;
        _removePhoto = false;
        _dirty = true;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  String? _storeError(AppLocalizations l) => _submitted && _store.text.trim().isEmpty ? l.cashEntryStoreRequired : null;
  String? _amountError(AppLocalizations l, String locale) =>
      _submitted && CashFormat.parseAmount(locale, _amount.text) == null ? l.cashEntryAmountInvalid : null;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    setState(() => _submitted = true);
    final cents = CashFormat.parseAmount(locale, _amount.text);
    if (_store.text.trim().isEmpty || cents == null || _gone || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final e = widget.entry;
      if (e == null) {
        await _c.addEntry(widget.roomId, date: _date, store: _store.text, amountCents: cents, note: _note.text, photo: _newPhoto);
      } else {
        await _c.editEntry(
          widget.roomId,
          e.copyWith(date: _date, store: _store.text, amountCents: cents, note: _note.text),
          newPhoto: _newPhoto,
          removePhoto: _removePhoto && _newPhoto == null,
        );
      }
      _dirty = false;
      nav.pop(true);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, err))));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final e = widget.entry;
    if (e == null || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l.cashEntryDeleteConfirm),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashEntryDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await _c.deleteEntry(widget.roomId, e.id);
      _dirty = false;
      nav.pop(true);
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, err))));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.cashDiscardTitle),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cashKeepEditing)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashDiscard)),
        ],
      ),
    );
    if (discard == true) {
      setState(() => _dirty = false);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final e = widget.entry;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(e == null ? l.cashAddEntry : l.cashEditEntry)),
        body: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          if (_gone)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Semantics(liveRegion: true, child: Text(l.cashBookGone, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.cashEntryDate),
            subtitle: Text(CashFormat.date(locale, _date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _saving ? null : _pickDate,
          ),
          TextField(
            controller: _store,
            enabled: !_saving,
            maxLength: CashBookLimits.maxStore,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.cashEntryStore, errorText: _storeError(l)),
            onChanged: (_) => _touch(),
          ),
          TextField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(20)],
            decoration: InputDecoration(labelText: l.cashEntryAmount, errorText: _amountError(l, locale)),
            onChanged: (_) => _touch(),
          ),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLength: CashBookLimits.maxNote,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.cashEntryNote),
            onChanged: (_) => _touch(),
          ),
          const SizedBox(height: 8),
          Semantics(header: true, child: Text(l.cashReceipt, style: Theme.of(context).textTheme.titleMedium)),
          if (e?.receipt != null && !_removePhoto && _newPhoto == null) CashReceiptPicture(controller: _c, roomId: widget.roomId, entry: e!),
          if (_newPhoto != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: <Widget>[const Icon(Icons.check_circle_outline), const SizedBox(width: 8), Text(l.cashReceiptAttached)])),
          Wrap(spacing: 8, children: <Widget>[
            TextButton.icon(
              onPressed: _saving ? null : _choosePhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(_hasPhoto ? l.cashReceiptReplace : l.cashReceiptAdd),
            ),
            if (_hasPhoto)
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _newPhoto = null;
                          _removePhoto = e?.receipt != null;
                          _dirty = true;
                        }),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.cashReceiptRemove),
              ),
          ]),
          if (_saving && _newPhoto != null) Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(liveRegion: true, child: Text(l.cashReceiptPreparing))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving || _gone ? null : _save, child: Text(l.cashEntrySave)),
          if (e != null) TextButton(onPressed: _saving ? null : _delete, child: Text(l.cashEntryDelete)),
        ]),
      ),
    );
  }
}
