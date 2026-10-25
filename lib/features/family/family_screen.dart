import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/family.dart';
import '../../domain/permissions.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import '../moderation/moderation_actions.dart';
import '../common/prompt_dialog.dart';
import '../presence/presence_view.dart';
import 'invite_dialog.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).gateway;
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final f = g.family;
        if (f == null) return Center(child: Text(l.emptyFamily));
        final t = AuroraTokens.of(context);
        final mod = Permissions.isModerator(f);
        return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Expanded(child: Semantics(header: true, child: Text(f.name, style: Theme.of(context).textTheme.headlineSmall))),
                if (Permissions.canConfigure(f))
                  IconButton(tooltip: l.familyRename, icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(context, g, f)),
              ]),
              if (mod && f.needsSecondModerator) ...<Widget>[
                const SizedBox(height: 8),
                Row(children: <Widget>[
                  Icon(Icons.info_outline, size: 18, color: t.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.familySecondModerator)),
                ]),
              ],
              if (!mod) ...<Widget>[const SizedBox(height: 8), Text(l.familyOnlyModerators, style: Theme.of(context).textTheme.bodySmall)],
            ]),
          ),
          if (mod) ...<Widget>[
            const SizedBox(height: 12),
            _InvitePanel(gateway: g, roomId: f.roomId),
            if (f.requests.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Semantics(header: true, child: Text(l.familyRequests, style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(height: 8),
              for (final m in f.requests) _RequestTile(gateway: g, member: m),
            ],
          ],
          const SizedBox(height: 16),
          Semantics(header: true, child: Text(l.familyMembers, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 8),
          for (final m in f.members.where((m) => m.status != MemberStatus.requested)) _MemberTile(gateway: g, family: f, member: m),
        ]);
      },
    );
  }

  static Future<void> _rename(BuildContext context, MatrixGateway g, Family f) async {
    final l = AppLocalizations.of(context);
    final name = await TextPromptDialog.show(
      context,
      TextPromptDialog(title: l.familyRename, label: l.familyName, confirmLabel: l.save, initial: f.name, maxLength: 60),
    );
    if (name == null || !context.mounted) return;
    try {
      await g.renameFamily(name);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.familyRenamed)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }
}

Future<void> _act(BuildContext context, Future<void> Function() op, {String? success}) async {
  final l = AppLocalizations.of(context);
  final m = ScaffoldMessenger.of(context);
  try {
    await op();
    if (success != null) m.showSnackBar(SnackBar(content: Text(success)));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(errorText(l, e))));
  }
}

Future<bool> _confirm(BuildContext context, String title, String body, String action) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
          ],
        ),
      ) ??
      false;
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.gateway, required this.family, required this.member});
  final MatrixGateway gateway;
  final Family family;
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final m = member;
    final canPromote = Permissions.canPromote(family, m);
    final canRemove = Permissions.canRemove(family, m);
    final canVerify = m.status == MemberStatus.joined && m.userId != family.myUserId;
    final canAccept = canVerify && m.identity == IdentityStatus.changed;
    final services = AppScope.of(context);
    final blocked = ModerationActions.isBlocked(services, m.userId);
    final canWrite = canVerify && m.identity != IdentityStatus.changed && !blocked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: <Widget>[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(m.displayName, style: Theme.of(context).textTheme.titleMedium),
              Text(m.userId, style: monoStyle(context, size: 12, color: t.textSecondary)),
              if (blocked) ...<Widget>[
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Icon(Icons.block, size: 14, color: t.textSecondary),
                  const SizedBox(width: 4),
                  Text(l.memberBlockedBadge, style: Theme.of(context).textTheme.labelSmall),
                ]),
              ],
              if (m.status == MemberStatus.joined) ...<Widget>[
                const SizedBox(height: 4),
                PresenceStatusText(userId: m.userId),
              ],
              if (m.status == MemberStatus.joined && m.userId != family.myUserId) ...<Widget>[
                const SizedBox(height: 4),
                _IdentityRow(identity: m.identity),
                if (m.identity == IdentityStatus.changed) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(l.identityChangedWarning(m.displayName), style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ]),
          ),
          StatusBadge(
            label: switch (m.status) {
              MemberStatus.invited => l.statusInvited,
              MemberStatus.requested => l.statusRequested,
              MemberStatus.joined => m.role == Role.moderator ? l.familyRoleModerator : l.familyRoleMember,
            },
            color: m.role == Role.moderator ? t.primary : t.textMuted,
            icon: m.role == Role.moderator ? Icons.shield_outlined : null,
          ),
          if (canWrite)
            IconButton(
              tooltip: '${l.familyWriteMessage}: ${m.displayName}',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => _writeTo(context),
            ),
          if (canPromote || canRemove || canVerify)
            PopupMenuButton<String>(
              tooltip: l.memberActionsTooltip(m.displayName),
              onSelected: (v) async {
                switch (v) {
                  case 'promote':
                    if (await _confirm(context, l.familyMemberPromote, l.familyMemberPromoteConfirm(m.displayName), l.familyMemberPromote) && context.mounted) {
                      await _act(context, () => gateway.promote(m.userId), success: l.familyDone);
                    }
                  case 'remove':
                    if (await _confirm(context, l.familyMemberRemove, l.familyMemberRemoveConfirm(m.displayName), l.familyMemberRemove) && context.mounted) {
                      await _act(context, () => gateway.removeMember(m.userId), success: l.familyDone);
                    }
                  case 'block':
                    await ModerationActions.block(context, services, userId: m.userId, name: m.displayName);
                  case 'unblock':
                    await ModerationActions.unblock(context, services, userId: m.userId, name: m.displayName);
                  case 'verify':
                    await _act(context, () => gateway.startVerification(userId: m.userId));
                  case 'accept':
                    if (await _confirm(context, l.identityAccept, l.identityAcceptConfirm, l.identityAccept) && context.mounted) {
                      await _act(context, () => gateway.acceptIdentityChange(m.userId), success: l.familyDone);
                    }
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                if (canVerify) PopupMenuItem<String>(value: 'verify', child: Text(l.securityVerifyPerson)),
                if (canAccept) PopupMenuItem<String>(value: 'accept', child: Text(l.identityAccept)),
                if (canPromote) PopupMenuItem<String>(value: 'promote', child: Text(l.familyMemberPromote)),
                if (canRemove) PopupMenuItem<String>(value: 'remove', child: Text(l.familyMemberRemove)),
                if (canVerify)
                  PopupMenuItem<String>(
                    value: blocked ? 'unblock' : 'block',
                    child: Text(blocked ? l.unblockAction : l.chatBlockSender(m.displayName)),
                  ),
              ],
            ),
        ]),
      ),
    );
  }
}

extension on _MemberTile {
  /// Eröffnet den Einzelchat und wechselt zum Chat.
  Future<void> _writeTo(BuildContext context) async {
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      services.chatRequest.value = await gateway.startDirectChat(member.userId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.identity});
  final IdentityStatus identity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final (IconData icon, String label, Color color) = switch (identity) {
      IdentityStatus.verified => (Icons.verified_user_outlined, l.identityVerified, t.success),
      IdentityStatus.pinned => (Icons.shield_outlined, l.identityPinned, t.textSecondary),
      IdentityStatus.unknown => (Icons.help_outline, l.identityUnknown, t.textSecondary),
      IdentityStatus.changed => (Icons.gpp_maybe_outlined, l.identityChanged, t.danger),
    };
    return Row(children: <Widget>[
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 12))),
    ]);
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.gateway, required this.member});
  final MatrixGateway gateway;
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final valid = member.request == RequestCheck.valid;
    final byCode = member.request == RequestCheck.code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassCard(
        glow: t.warning,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(l.familyRequestFrom(member.displayName), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Row(children: <Widget>[
            Icon(valid ? Icons.check_circle_outline : Icons.warning_amber_outlined, size: 18, color: valid ? t.success : t.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(switch (member.request) {
                RequestCheck.valid => l.familyRequestCheckValid,
                RequestCheck.expired => l.familyRequestCheckExpired,
                RequestCheck.code => l.familyRequestCheckCode(member.userId),
                _ => l.familyRequestCheckUnknown,
              }),
            ),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
            TextButton(onPressed: () => _act(context, () => gateway.rejectRequest(member.userId)), child: Text(l.familyRequestReject)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: !valid && !byCode
                  ? null
                  : () async {
                      if (await _confirm(context, l.familyRequestApprove, l.familyRequestApproveConfirm(member.userId), l.familyRequestApprove) && context.mounted) {
                        await _act(context, () => gateway.approveRequest(member.userId), success: l.familyDone);
                      }
                    },
              child: Text(l.familyRequestApprove),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _InvitePanel extends StatefulWidget {
  const _InvitePanel({required this.gateway, this.roomId});
  final MatrixGateway gateway;

  /// Familien-Code (Raum-ID) zum Weitergeben; `null` ohne Familie.
  final String? roomId;

  @override
  State<_InvitePanel> createState() => _InvitePanelState();
}

class _InvitePanelState extends State<_InvitePanel> {
  final TextEditingController _id = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _inviteById() async {
    final l = AppLocalizations.of(context);
    final id = _id.text.trim();
    if (!MatrixIds.isUserId(id)) {
      setState(() => _error = l.familyInviteInvalidId);
      return;
    }
    setState(() => _error = null);
    // Eingeladene erhalten Nachrichtenschlüssel schon vor der Annahme (SDK-Verhalten, SA-2): Rückfrage.
    if (!await _confirm(context, l.familyInvite, l.familyInviteConfirm(id), l.familyInviteSend) || !mounted) return;
    await _act(context, () => widget.gateway.inviteUser(id), success: l.familyInviteSent);
    if (mounted) _id.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Semantics(header: true, child: Text(l.familyInvite, style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 8),
        Text(l.familyInviteIntro),
        const SizedBox(height: 12),
        if (widget.roomId != null) ...<Widget>[
          Text(l.familyCodeTitle, style: Theme.of(context).textTheme.titleSmall),
          Text(l.familyCodeHint, style: Theme.of(context).textTheme.bodySmall),
          Row(children: <Widget>[
            Expanded(child: SelectableText(widget.roomId!, style: monoStyle(context, size: 12))),
            IconButton(
              tooltip: l.familyCodeCopy,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.roomId!));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.familyCodeCopied)));
              },
            ),
          ]),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(l.familyInviteSomeone),
          onPressed: () => showInviteDialog(context, widget.gateway),
        ),
        // Einladen per Benutzer-ID ist selten nötig und verlangt Fachwissen: nur unter „Erweitert“.
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.advTitle),
          children: <Widget>[
            TextField(
              controller: _id,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(labelText: l.familyInviteById, hintText: l.familyInviteByIdHint, errorText: _error),
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _inviteById, child: Text(l.familyInviteSend))),
          ],
        ),
      ]),
    );
  }
}
