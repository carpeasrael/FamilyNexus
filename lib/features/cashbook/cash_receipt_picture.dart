import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_log.dart';
import '../../domain/cash_book.dart';
import '../../domain/cash_receipt_check.dart';
import '../../l10n/gen/app_localizations.dart';
import 'cash_book_controller.dart';

/// Zeigt den Bon eines Eintrags (#311, E-113): Das Bild erscheint **nur** bei geprüftem Zustand `ok` und wird aus
/// Rohpixeln gezeichnet (`RawImage`), nie über `Image.memory` oder einen nativen Decoder. Jeder andere Zustand zeigt
/// einen Platzhalter; bei „momentan nicht abrufbar“ gibt es „Erneut versuchen“.
class CashReceiptPicture extends StatefulWidget {
  const CashReceiptPicture({super.key, required this.controller, required this.roomId, required this.entry});

  final CashBookController controller;
  final String roomId;
  final CashEntry entry;

  @override
  State<CashReceiptPicture> createState() => _CashReceiptPictureState();
}

class _CashReceiptPictureState extends State<CashReceiptPicture> {
  BookReceiptStatus? _status;
  ui.Image? _image;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CashReceiptPicture old) {
    super.didUpdateWidget(old);
    if (old.entry.receipt != widget.entry.receipt || old.roomId != widget.roomId) _load();
  }

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    if (mounted) setState(() => _loading = true);
    BookReceiptStatus status;
    ui.Image? image;
    try {
      final v = await widget.controller.loadReceipt(widget.roomId, widget.entry);
      status = v.status;
      final p = v.preview;
      if (p != null) {
        final c = Completer<ui.Image>();
        ui.decodeImageFromPixels(p.rgba, p.width, p.height, ui.PixelFormat.rgba8888, c.complete);
        image = await c.future;
      }
    } catch (e) {
      AppLog.w('cashbook', 'Bon konnte nicht angezeigt werden (${e.runtimeType})');
      status = BookReceiptStatus.unavailable;
    }
    if (!mounted || gen != _generation) {
      image?.dispose();
      return;
    }
    final old = _image;
    setState(() {
      _status = status;
      _image = image;
      _loading = false;
    });
    old?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return Padding(padding: const EdgeInsets.all(16), child: Center(child: Semantics(label: l.cashLoading, child: const CircularProgressIndicator())));
    }
    final image = _image;
    if (_status == BookReceiptStatus.ok && image != null) {
      return Semantics(
        label: l.cashReceiptSemantics,
        image: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: InteractiveViewer(minScale: 1, maxScale: 5, child: RawImage(image: image, fit: BoxFit.contain)),
        ),
      );
    }
    final text = switch (_status) {
      BookReceiptStatus.invalid => l.cashReceiptInvalid,
      BookReceiptStatus.unavailable => l.cashReceiptUnavailable,
      _ => l.cashReceiptMissing,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
        const Icon(Icons.receipt_long_outlined),
        Semantics(liveRegion: true, child: Text(text)),
        if (_status == BookReceiptStatus.unavailable) TextButton(onPressed: _load, child: Text(l.cashRetry)),
      ]),
    );
  }
}
