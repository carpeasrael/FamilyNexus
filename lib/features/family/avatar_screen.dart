import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/member_avatars.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'avatar_presets_ui.dart';
import 'member_avatar_view.dart';

/// Eigenen Avatar wählen (#422, E-101): zwölf eingebaute Avatare oder die Initialen. Kein optimistischer Wert: nach
/// dem Speichern gilt die Wahl als „wird übernommen“, bis `avatarOf(ich)` sie meldet, längstens [pendingLimit].
class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key, required this.services, this.pendingLimit = const Duration(seconds: 15)});

  final AppServices services;

  /// Nur die Anzeigefrist von „wird übernommen“; danach zeigt der Bildschirm den tatsächlichen Stand.
  final Duration pendingLimit;

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  MatrixGateway get _g => widget.services.gateway;

  bool _dirty = false;
  String? _picked;
  bool _saving = false;

  /// Gespeicherte, aber noch nicht gemeldete Wahl (`preset == null`: Initialen).
  ({String? preset})? _pending;
  Timer? _timer;

  String get _me => _g.family?.myUserId ?? _g.userId ?? '';

  String? get _actual => _g.avatarOf(_me);

  String? get _selected => _pending != null ? _pending!.preset : (_dirty ? _picked : _actual);

  @override
  void initState() {
    super.initState();
    _g.addListener(_onChange);
    _g.avatarRevision.addListener(_onChange);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _g.removeListener(_onChange);
    _g.avatarRevision.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {
      final p = _pending;
      if (p != null && _actual == p.preset) {
        _pending = null;
        _dirty = false;
        _timer?.cancel();
      }
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    final choice = _picked;
    setState(() => _saving = true);
    try {
      await _g.setMemberAvatar(choice);
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (_actual == choice) {
          _dirty = false;
        } else {
          _pending = (preset: choice);
          _timer?.cancel();
          _timer = Timer(widget.pendingLimit, () {
            if (!mounted) return;
            // Die Anzeigefrist ist um: der tatsächliche Stand gilt, auch wenn ein anderes Gerät etwas anderes gesetzt hat.
            setState(() {
              _pending = null;
              _dirty = false;
            });
          });
        }
      });
      m.showSnackBar(SnackBar(content: Text(l.avatarSaved)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      m.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final availability = _g.avatarAvailability;
    final name = _g.family?.member(_me)?.displayName ?? '';
    final colorIndex = personColorOf(widget.services, _me);
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: Text(l.avatarTitle)),
      body: switch (availability) {
        AvatarAvailability.unknown => Center(child: CircularProgressIndicator(semanticsLabel: l.avatarLoading)),
        AvatarAvailability.needsModerator => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            GlassCard(
              child: Row(children: <Widget>[
                Icon(Icons.info_outline, color: t.warning),
                const SizedBox(width: 12),
                Expanded(child: Text(l.avatarNeedsModerator)),
              ]),
            ),
          ]),
        AvatarAvailability.settable => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            GlassCard(
              child: Row(children: <Widget>[
                AvatarFace(preset: selected, letter: letter, size: 64, colorIndex: colorIndex),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(l.avatarPreview, style: Theme.of(context).textTheme.labelMedium),
                    Text(name.isEmpty ? _me : name, style: Theme.of(context).textTheme.titleMedium),
                    Text(selected == null ? l.avatarInitials : AvatarPresetsUi.name(l, selected), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _Choice(
                label: l.avatarInitials,
                selected: selected == null,
                face: AvatarFace(preset: null, letter: letter, size: 48, colorIndex: colorIndex),
                onTap: _locked ? null : () => _pick(null),
              ),
              for (final id in AvatarPresets.all)
                _Choice(
                  label: AvatarPresetsUi.name(l, id),
                  selected: selected == id,
                  face: AvatarFace(preset: id, letter: letter, size: 48, colorIndex: colorIndex),
                  onTap: _locked ? null : () => _pick(id),
                ),
            ]),
            const SizedBox(height: 16),
            Text(l.avatarVisibility, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            if (_pending != null)
              Row(children: <Widget>[
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(l.avatarPending)),
              ])
            else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving || !_dirty || _picked == _actual ? null : _save,
                  child: Text(l.save),
                ),
              ),
          ]),
      },
    );
  }

  bool get _locked => _saving || _pending != null;

  void _pick(String? id) => setState(() {
        _picked = id;
        _dirty = true;
      });
}

/// Eine Auswahl im Raster: Avatar mit Beschriftung, die gewählte mit Häkchen und Text „Ausgewählt“ (nie nur Farbe).
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.face, required this.onTap});

  final String label;
  final bool selected;
  final Widget face;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      hint: selected ? l.avatarSelected : null,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 92,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? t.primary : t.textMuted.withValues(alpha: 0.4), width: selected ? 2 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Stack(clipBehavior: Clip.none, children: <Widget>[
              face,
              if (selected)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 16, color: t.onPrimary),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
            if (selected) Text(l.avatarSelected, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
