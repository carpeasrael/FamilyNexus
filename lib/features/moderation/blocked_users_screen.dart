import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/family.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import 'moderation_actions.dart';

/// Liste der lokal blockierten Mitglieder mit „Blockierung aufheben“ (E-48).
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final services = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsBlockedUsers)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[services.settings, services.gateway]),
          builder: (context, _) {
            final blocked = services.settings.settings.blockedUsers;
            if (blocked.isEmpty) return Center(child: Text(l.blockedUsersEmpty));
            final members = <String, String>{
              for (final m in services.gateway.family?.members ?? const <FamilyMember>[]) m.userId: m.displayName,
            };
            return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
              for (final id in blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Row(children: <Widget>[
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          if (members[id] != null) Text(members[id]!, style: Theme.of(context).textTheme.titleMedium),
                          Text(id, style: monoStyle(context, size: 12, color: t.textSecondary)),
                        ]),
                      ),
                      TextButton(
                        onPressed: () => ModerationActions.unblock(context, services, userId: id, name: members[id] ?? id),
                        child: Text(l.unblockAction),
                      ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
