import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/invite_link.dart';
import '../../l10n/gen/app_localizations.dart';

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
    final raw = _link.text.trim();
    final link = InviteLink.tryParse(raw, now: DateTime.now());
    if (link == null || !link.isValidAt(DateTime.now())) {
      setState(() => _error = l.joinLinkInvalid);
      return;
    }
    await s.settings.update((c) => c.copyWith(pendingInvite: InviteLink.normalized(raw)));
    s.pendingInvite.value = link;
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
        decoration: InputDecoration(labelText: l.joinLinkLabel, errorText: _error),
      ),
      const SizedBox(height: 8),
      Text(l.inviteStepNoLink, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _submit, child: Text(l.next))),
    ]);
  }
}
