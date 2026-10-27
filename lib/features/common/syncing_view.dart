import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/matrix/matrix_gateway.dart';
import '../../l10n/gen/app_localizations.dart';

/// „Synchronisiere …“ mit Ausweg: Dauert es ungewöhnlich lange, erscheinen ein Hinweis und
/// „Erneut versuchen“, statt endlos zu laden (#24).
class SyncingView extends StatefulWidget {
  const SyncingView({super.key, required this.gateway});

  final MatrixGateway gateway;

  /// Ab dieser Dauer gilt das Warten als ungewöhnlich lang.
  static const Duration slowAfter = Duration(seconds: 30);

  @override
  State<SyncingView> createState() => _SyncingViewState();
}

class _SyncingViewState extends State<SyncingView> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(SyncingView.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _slow = false);
    _arm();
    await widget.gateway.retrySync();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Flexible(child: Text(l.syncing)),
      ]),
      if (_slow) ...<Widget>[
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text(l.syncSlow)),
        TextButton(onPressed: _retry, child: Text(l.retry)),
      ],
    ]);
  }
}
