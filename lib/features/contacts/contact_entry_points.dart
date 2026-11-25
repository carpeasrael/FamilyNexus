import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import 'contact_controller.dart';
import 'contacts_screen.dart';

void openContacts(BuildContext context, ContactController controller) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactsScreen(controller: controller)));

/// Eintrag „Kontakte“ in den Einstellungen (#119, K3b-1); nur, wenn es einen Controller gibt (hinter `ContactFlags.enabled`).
class ContactSettingsTile extends StatelessWidget {
  const ContactSettingsTile({super.key, required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.public),
          title: Text(l.contactsTitle),
          subtitle: Text(l.contactsSettingsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openContacts(context, controller),
        ),
      ),
    );
  }
}
