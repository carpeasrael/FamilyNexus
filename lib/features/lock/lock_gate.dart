import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';

/// Verdeckt die App, solange sie gesperrt ist, und reagiert auf Wechsel in den Hintergrund.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = AppScope.read(context).lock;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        lock.onPaused();
      case AppLifecycleState.resumed:
        lock.onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = AppScope.of(context).lock;
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) => Stack(children: <Widget>[
        // Inhalt bleibt erhalten (Zustand), ist aber für Bedienung und Bedienhilfen gesperrt.
        ExcludeSemantics(
          excluding: lock.locked,
          child: IgnorePointer(ignoring: lock.locked, child: widget.child),
        ),
        if (lock.locked) const Positioned.fill(child: LockScreen()),
      ]),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_asked) {
      _asked = true;
      // Beim Erscheinen sofort die Geräteabfrage anbieten.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlock();
      });
    }
  }

  Future<void> _unlock() async {
    final l = AppLocalizations.of(context);
    await AppScope.read(context).lock.unlock(l.lockReason);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Semantics(header: true, child: Text(l.lockTitle, style: Theme.of(context).textTheme.headlineSmall)),
                  const SizedBox(height: 8),
                  Text(l.lockHint, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _unlock, child: Text(l.lockUnlock)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
