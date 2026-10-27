import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/chat.dart';
import '../../domain/moderation.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';

/// Blockieren und Melden aus Chat und Familie (E-48).
class ModerationActions {
  const ModerationActions._();

  static bool isBlocked(AppServices s, String userId) => s.settings.settings.blockedUsers.contains(userId);

  /// Fragt nach und blockiert [userId] auf diesem Gerät. `true`, wenn blockiert wurde.
  static Future<bool> block(BuildContext context, AppServices services, {required String userId, required String name}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.blockConfirmTitle(name)),
            content: Text(l.blockConfirmBody(name)),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.blockConfirmAction)),
            ],
          ),
        ) ??
        false;
    if (!ok) return false;
    final saved = await services.settings.update((s) => s.copyWith(blockedUsers: BlockedUsers.add(s.blockedUsers, userId)));
    messenger.showSnackBar(SnackBar(content: Text(saved ? l.blockDone(name) : l.errUnknown)));
    return saved;
  }

  static Future<void> unblock(BuildContext context, AppServices services, {required String userId, required String name}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await services.settings.update((s) => s.copyWith(blockedUsers: BlockedUsers.remove(s.blockedUsers, userId)));
    messenger.showSnackBar(SnackBar(content: Text(saved ? l.unblockDone(name) : l.errUnknown)));
  }

  /// Zeigt den Meldedialog und sendet die Meldung. Danach wird angeboten, den Absender zu blockieren.
  static Future<void> report(
    BuildContext context,
    AppServices services, {
    required ChatMessage message,
    required String threadId,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final request = await showDialog<ReportRequest>(
      context: context,
      builder: (_) => _ReportDialog(messageId: message.id, threadId: threadId, server: services.gateway.server?.host ?? ''),
    );
    if (request == null) return;
    try {
      await services.gateway.reportMessage(request);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      return;
    }
    if (!context.mounted) return;
    final canBlock = !isBlocked(services, message.senderId);
    messenger.showSnackBar(SnackBar(
      content: Text(l.reportDone),
      duration: const Duration(seconds: 8),
      // Ohne `persist: false` bleibt ein SnackBar mit Aktion bis zum Antippen stehen (Flutter-Standard)
      // und verdeckt die untere Bedienung (Issue #45).
      persist: false,
      action: canBlock
          ? SnackBarAction(
              label: l.reportBlockOffer,
              onPressed: () => block(context, services, userId: message.senderId, name: message.senderName),
            )
          : null,
    ));
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.messageId, required this.threadId, required this.server});
  final String messageId;
  final String threadId;
  final String server;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _details = TextEditingController();
  ReportCategory _category = ReportCategory.harassment;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l, ReportCategory c) => switch (c) {
        ReportCategory.spam => l.reportCategorySpam,
        ReportCategory.harassment => l.reportCategoryHarassment,
        ReportCategory.inappropriate => l.reportCategoryInappropriate,
        ReportCategory.other => l.reportCategoryOther,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.reportTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(l.reportIntro(widget.server), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          RadioGroup<ReportCategory>(
            groupValue: _category,
            onChanged: (v) => setState(() => _category = v ?? _category),
            child: Column(children: <Widget>[
              for (final c in ReportCategory.values)
                RadioListTile<ReportCategory>(dense: true, contentPadding: EdgeInsets.zero, value: c, title: Text(_label(l, c))),
            ]),
          ),
          TextField(
            controller: _details,
            maxLength: ReportRequest.maxDetailsLength,
            maxLines: 3,
            minLines: 1,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(hintText: l.reportDetailsHint),
          ),
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ReportRequest(messageId: widget.messageId, threadId: widget.threadId, category: _category, details: _details.text),
          ),
          child: Text(l.reportSend),
        ),
      ],
    );
  }
}
