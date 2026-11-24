import 'package:flutter/material.dart';

import '../../domain/family.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import 'cash_book_controller.dart';

/// Mitglieder eines Kassenbuchs (#311, E-113). Einladen und Entfernen nur als Ersteller, mit Datenschutz-Hinweis bei
/// **jedem** Einladen; der Ersteller kann sein Buch nicht verlassen.
class CashBookMembersScreen extends StatefulWidget {
  const CashBookMembersScreen({super.key, required this.controller, required this.roomId});

  final CashBookController controller;
  final String roomId;

  @override
  State<CashBookMembersScreen> createState() => _CashBookMembersScreenState();
}

class _CashBookMembersScreenState extends State<CashBookMembersScreen> {
  Future<List<CashBookMemberView>>? _members;
  bool _busy = false;

  CashBookController get _c => widget.controller;

  CashBookView? get _view {
    for (final b in _c.books) {
      if (b.roomId == widget.roomId) return b;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    final v = _view;
    _members = v == null ? Future<List<CashBookMemberView>>.value(const <CashBookMemberView>[]) : _c.members(v);
  }

  /// Änderungen des Controllers (Sperre, Rollenverlust, Familienwechsel): neu zeichnen, damit nichts Veraltetes bedienbar bleibt.
  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    super.dispose();
  }

  void _reload() {
    final v = _view;
    final f = v == null ? Future<List<CashBookMemberView>>.value(const <CashBookMemberView>[]) : _c.members(v);
    setState(() {
      _members = f;
    });
  }

  Future<void> _act(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await op();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  Future<void> _invite(CashBookView v) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final List<FamilyMember> candidates;
    try {
      candidates = await _c.inviteCandidates(v);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.cashInviteNone)));
      return;
    }
    final picked = await showDialog<FamilyMember>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(l.cashInvite),
        children: <Widget>[for (final m in candidates) SimpleDialogOption(onPressed: () => Navigator.pop(d, m), child: Text(m.displayName.isEmpty ? m.userId : m.displayName))],
      ),
    );
    if (picked == null || !mounted) return;
    final name = picked.displayName.isEmpty ? picked.userId : picked.displayName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.cashInviteConfirmTitle(name)),
        content: Text(l.cashInviteConfirmBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashInviteAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _act(() => _c.inviteMember(v, picked.userId));
  }

  Future<void> _remove(CashBookView v, CashBookMemberView m) async {
    final l = AppLocalizations.of(context);
    final name = m.name.isEmpty ? m.userId : m.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l.cashRemoveConfirm(name)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.cashRemove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _act(() => _c.removeMember(v, m.userId));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = _view;
    if (v == null || !_c.available) {
      return Scaffold(appBar: AppBar(title: Text(l.cashMembersTitle)), body: Center(child: Text(l.cashBookGone)));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.cashMembersTitle)),
      body: FutureBuilder<List<CashBookMemberView>>(
        future: _members,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Semantics(liveRegion: true, child: Text(errorText(l, snap.error!)))));
          }
          final list = snap.data;
          if (list == null) return Center(child: Semantics(label: l.cashLoading, child: const CircularProgressIndicator()));
          return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            for (final m in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(m.isCreator ? Icons.star_outline : Icons.person_outline),
                title: Text(m.name.isEmpty ? m.userId : m.name),
                subtitle: Text(<String>[if (m.isCreator) l.cashMemberCreator, m.joined ? l.cashMemberJoined : l.cashMemberInvited].join(' · ')),
                trailing: m.canRemove ? TextButton(onPressed: _busy ? null : () => _remove(v, m), child: Text(l.cashRemove)) : null,
              ),
            if (v.mine)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(onPressed: _busy ? null : () => _invite(v), icon: const Icon(Icons.person_add_alt_outlined), label: Text(l.cashInvite)),
              )
            else
              const SizedBox.shrink(),
            if (v.mine) Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.cashCreatorCannotLeave)),
          ]);
        },
      ),
    );
  }
}
