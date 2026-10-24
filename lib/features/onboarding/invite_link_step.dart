import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/invite_link.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/invite_link_text.dart';

/// „Ich wurde eingeladen“, aber die App wurde nicht über den Link geöffnet: Link einfügen (E-56).
/// Danach geht es mit „Konto erstellen“ beim Anbieter des Einladenden weiter.
class InviteLinkStep extends StatefulWidget {
  const InviteLinkStep({super.key});

  @override
  State<InviteLinkStep> createState() => _InviteLinkStepState();
}

class _InviteLinkStepState extends State<InviteLinkStep> {
  final TextEditingController _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final s = AppScope.read(context);
    final check = InviteLink.check(_link.text, now: DateTime.now());
    final problem = check.problem;
    if (problem != null) {
      setState(() => _error = inviteLinkProblemText(l, problem));
      return;
    }
    await s.settings.update((c) => c.copyWith(pendingInvite: check.raw));
    s.pendingInvite.value = check.link;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.inviteStepBody),
      const SizedBox(height: 12),
      TextField(
        controller: _link,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        keyboardType: TextInputType.url,
        minLines: 1,
        maxLines: 3,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: l.joinLinkLabel, errorText: _error, errorMaxLines: 4),
      ),
      const SizedBox(height: 8),
      Text(l.inviteStepNoLink, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _submit, child: Text(l.next))),
    ]);
  }
}
