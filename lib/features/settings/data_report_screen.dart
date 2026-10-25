import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../app/app_version.dart';
import '../../domain/data_inventory.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'data_report.dart';

enum DataReportKind { local, online }

/// Zeigt das Protokoll der lokal bzw. online gespeicherten Daten; kopieren oder als Textdatei speichern.
class DataReportScreen extends StatefulWidget {
  const DataReportScreen({super.key, required this.kind});
  final DataReportKind kind;

  @override
  State<DataReportScreen> createState() => _DataReportScreenState();
}

class _DataReportScreenState extends State<DataReportScreen> {
  Future<String>? _report;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _report ??= _build(AppLocalizations.of(context), AppScope.read(context));
  }

  Future<String> _build(AppLocalizations l, AppServices services) async {
    final now = DateTime.now();
    final gateway = services.gateway;
    switch (widget.kind) {
      case DataReportKind.online:
        return DataReport.online(l: l, inventory: await gateway.dataInventory(), now: now, version: appVersion);
      case DataReportKind.local:
        final local = services.dataInventory;
        if (local == null) throw StateError('Keine lokale Datenbank');
        OnlineInventory? matrix;
        try {
          matrix = await gateway.dataInventory(refresh: false);
        } catch (_) {
          // Abgemeldet: der Abschnitt meldet „nicht verfügbar“.
        }
        return DataReport.local(l: l, inventory: await local.read(), matrix: matrix, now: now, version: appVersion);
    }
  }

  String _title(AppLocalizations l) => widget.kind == DataReportKind.local ? l.reportLocalTitle : l.reportOnlineTitle;

  Future<void> _copy(String text) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l.reportCopied)));
  }

  Future<void> _save(String text) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = AppScope.read(context).files;
    final now = DateTime.now();
    final date = DataReport.formatTime(now).split(' ').first;
    final name = 'familynexus-${widget.kind.name}-$date.txt';
    try {
      await files.saveFile(name: name, bytes: utf8.encode(text), mimeType: 'text/plain');
      messenger.showSnackBar(SnackBar(content: Text(l.reportSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<String>(
      future: _report,
      builder: (context, snap) {
        final text = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(_title(l)),
            actions: <Widget>[
              if (text != null) ...<Widget>[
                IconButton(icon: const Icon(Icons.copy_outlined), tooltip: l.reportCopy, onPressed: () => _copy(text)),
                IconButton(icon: const Icon(Icons.save_alt_outlined), tooltip: l.reportSave, onPressed: () => _save(text)),
              ],
            ],
          ),
          body: SafeArea(
            child: switch (snap.connectionState) {
              ConnectionState.done when snap.hasError => Center(
                  child: Padding(padding: const EdgeInsets.all(16), child: Text(errorText(l, snap.error!))),
                ),
              ConnectionState.done => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
                  GlassCard(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.reportWarning)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: SelectableText(text ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ),
                ]),
              _ => Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator())),
            },
          ),
        );
      },
    );
  }
}
