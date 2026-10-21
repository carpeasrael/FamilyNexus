import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/presence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';

/// Text zum Zustand, z. B. „Online“ oder „Zuletzt online vor 5 Min.“.
String presenceLabel(AppLocalizations l, PresenceInfo info, DateTime now) {
  switch (info.status) {
    case PresenceStatus.online:
      return l.presenceOnline;
    case PresenceStatus.unknown:
      return l.presenceUnknown;
    case PresenceStatus.offline:
      final seen = info.lastSeen;
      if (seen == null) return l.presenceOffline;
      final d = now.toUtc().difference(seen);
      final ago = d.inMinutes < 1
          ? l.presenceAgoNow
          : d.inMinutes < 60
              ? l.presenceAgoMinutes(d.inMinutes)
              : d.inHours < 24
                  ? l.presenceAgoHours(d.inHours)
                  : l.presenceAgoDays(d.inDays);
      return l.presenceLastSeen(ago);
  }
}

/// Wertet den Zustand eines Mitglieds zum Zeitpunkt [now] aus.
PresenceInfo presenceOf(AppServices services, String userId, DateTime now) =>
    PresenceBoard.evaluate(services.gateway.presence[userId], now);

/// Baut neu, wenn sich der Status ändert und alle 30 Sekunden (Ablauf von „online“).
class PresenceBuilder extends StatefulWidget {
  const PresenceBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<PresenceBuilder> createState() => _PresenceBuilderState();
}

class _PresenceBuilderState extends State<PresenceBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.gateway,
      builder: (context, _) => widget.builder(context, DateTime.now().toUtc()),
    );
  }
}

/// Punkt und Text: Der Zustand ist nie nur durch Farbe erkennbar. Für die eigene Person zeigt
/// die Anzeige, ob der Status geteilt wird.
class PresenceStatusText extends StatelessWidget {
  const PresenceStatusText({super.key, required this.userId, this.compact = false});
  final String userId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final services = AppScope.of(context);
    return PresenceBuilder(builder: (context, now) {
      final String label;
      final bool online;
      if (userId == services.gateway.userId) {
        final shared = services.settings.settings.shareOnlineStatus;
        label = shared ? l.presenceSelf : l.presenceSelfHidden;
        online = shared;
      } else {
        final info = presenceOf(services, userId, now);
        label = presenceLabel(l, info, now);
        online = info.status == PresenceStatus.online;
      }
      return Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          PresenceDot(online: online),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: online ? t.success : t.textSecondary),
              maxLines: compact ? 1 : 2,
            ),
          ),
        ]),
      );
    });
  }
}

/// Gefüllter Punkt = online, Ring = nicht online (Form und Text tragen die Information, nicht nur die Farbe).
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.online, this.size = 10});
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AuroraTokens.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? t.success : Colors.transparent,
          border: Border.all(color: online ? t.success : t.textMuted, width: 1.5),
          boxShadow: online && !t.reduceEffects ? <BoxShadow>[BoxShadow(color: t.success.withValues(alpha: 0.6), blurRadius: 6)] : null,
        ),
      ),
    );
  }
}
