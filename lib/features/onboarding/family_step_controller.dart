import 'package:flutter/foundation.dart';

import '../../data/matrix/matrix_gateway.dart';
import '../../domain/family.dart';
import '../../domain/family_code.dart';
import '../../domain/invite_link.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import '../common/invite_link_text.dart';
import '../settings/settings_controller.dart';

/// Was der Familienschritt zuerst zeigt: gründen (Weg „Neue Familie“), beitreten (Weg „Eingeladen“)
/// oder beides zur Auswahl (bestehendes Konto ohne Familie).
enum FamilyStepMode { create, join, choice }

/// Zustand und Aktionen des Familienschritts (AP-6a): gründen, per Link oder Code beitreten, Einladungen annehmen.
/// Abhängigkeiten kommen über den Konstruktor; Eingabefelder, Dialoge und Texte bleiben in der Oberfläche. Fehler
/// werden als Text erst beim Anzeigen aufgelöst ([errorMessage]), damit der Controller keinen `BuildContext` braucht.
class FamilyStepController extends ChangeNotifier {
  FamilyStepController({
    required this.gateway,
    required this.settings,
    required this.pendingInvite,
    required this.onFamilyReady,
    this.mode = FamilyStepMode.choice,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        join = mode == FamilyStepMode.join {
    pendingInvite.addListener(_onPending);
  }

  final MatrixGateway gateway;
  final SettingsController settings;
  final ValueNotifier<InviteLink?> pendingInvite;

  /// Wird aufgerufen, sobald eine Familie besteht (gegründet, beigetreten oder angenommen).
  final Future<void> Function() onFamilyReady;
  final FamilyStepMode mode;
  final DateTime Function() _clock;

  /// „Beitreten“ statt „Gründen“ gewählt.
  bool join;
  bool _busy = false;
  bool _completing = false;
  bool _creating = false;
  bool _disposed = false;

  /// Gerade gegründet: Erfolgsansicht mit „Jetzt einladen“ statt sofortigem Abschluss.
  String? _createdName;

  /// Der Nutzer hat trotz Einladung „andere Familie gründen oder beitreten“ gewählt.
  bool _showChoice = false;
  final Set<String> _autoAccepted = <String>{};
  String Function(AppLocalizations l)? _error;

  /// Name des Einladenden der zuletzt gesendeten Anfrage (für „… muss dich noch bestätigen“).
  String? _waitingFor;

  bool get busy => _busy;
  String? get createdName => _createdName;
  bool get showChoice => _showChoice;
  String? get waitingFor => _waitingFor;

  /// Während der Gründung meldet das Gateway die neue Familie schon; sie darf dann nicht als „bereits vorhanden“
  /// gelten (sonst fehlte die Erfolgsansicht).
  bool get creating => _creating;

  bool get hasError => _error != null;

  /// Der aktuelle Fehlertext in der Sprache von [l]; `null` ohne Fehler.
  String? errorMessage(AppLocalizations l) => _error?.call(l);

  /// Merkt, dass der Abschluss angestoßen wurde; `true` nur beim ersten Aufruf.
  bool beginCompleting() {
    if (_completing) return false;
    _completing = true;
    return true;
  }

  /// Merkt, dass die Einladung [roomId] automatisch angenommen wird; `true` nur beim ersten Aufruf.
  bool beginAutoAccept(String roomId) => _autoAccepted.add(roomId);

  void _update(void Function() change) {
    change();
    if (!_disposed) notifyListeners();
  }

  /// Ein per Deep Link oder QR eingegangener Link wird als Karte gezeigt; gehandelt wird erst auf Tipp.
  void _onPending() {
    if (_disposed || pendingInvite.value == null) return;
    _update(() {
      join = true;
      _showChoice = true;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() op) async {
    _update(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
    } catch (e) {
      if (!_disposed) _update(() => _error = (l) => errorText(l, e));
    } finally {
      if (!_disposed) _update(() => _busy = false);
    }
  }

  /// Wechselt zwischen den Reitern „Gründen“ und „Beitreten“.
  void selectJoin(bool value) => _update(() {
        join = value;
        _error = null;
      });

  /// „Stattdessen gründen oder beitreten“ im Einzelmodus: zeigt die Auswahl mit dem anderen Reiter.
  void switchMode() => _update(() {
        _showChoice = true;
        join = mode != FamilyStepMode.join;
      });

  /// „Andere Familie gründen oder beitreten“ bei vorhandener Einladung.
  void chooseOther() => _update(() => _showChoice = true);

  Future<void> create(String name) => _run(() async {
        _creating = true;
        try {
          await gateway.createFamily(name);
          if (!_disposed) _update(() => _createdName = name.trim());
        } finally {
          _creating = false;
        }
      });

  /// Eingefügter Link: prüfen und als Karte zeigen (gleicher Weg wie ein geöffneter Link). [clearInput] leert das
  /// Eingabefeld, sobald der Link angenommen ist.
  Future<void> submitLink(String raw, {required VoidCallback clearInput}) async {
    final check = InviteLink.check(raw, now: _clock(), ownHost: MatrixIds.serverName(gateway.userId ?? ''));
    final problem = check.problem;
    if (problem != null) {
      _update(() => _error = (l) => inviteLinkProblemText(l, problem));
      return;
    }
    clearInput();
    await settings.update((c) => c.copyWith(pendingInvite: check.raw));
    pendingInvite.value = check.link;
  }

  /// Anfrage über den Familien-Code (ohne Link): Der Moderator bestätigt ausdrücklich (E-65).
  Future<void> sendCode(String raw, {required VoidCallback clearInput}) async {
    final id = FamilyCode.parse(raw);
    if (id == null) {
      _update(() => _error = (l) => l.joinCodeInvalid);
      return;
    }
    await _run(() async {
      await gateway.requestToJoinByCode(id);
      _waitingFor = null;
      clearInput();
    });
  }

  Future<void> discard() async {
    pendingInvite.value = null;
    await settings.update((c) => c.copyWith(pendingInvite: null));
    if (!_disposed) _update(() => _error = null);
  }

  Future<void> send(InviteLink link) async {
    if (!link.isValidAt(_clock())) {
      _update(() => _error = (l) => l.joinLinkExpired);
      return;
    }
    await _run(() async {
      await gateway.requestToJoin(link);
      _waitingFor = link.inviterName ?? MatrixIds.localpart(link.inviter);
      await discard();
    });
  }

  /// Nimmt die Einladung an. Die Karte nennt Familie und Einladenden und warnt bei unerwarteten Einladungen (S5);
  /// der Tipp auf „Beitreten“ ist die Bestätigung.
  Future<void> accept(PendingInvitation inv) => _run(() async {
        await gateway.acceptInvitation(inv.roomId);
        await onFamilyReady();
      });

  Future<void> decline(PendingInvitation inv) => _run(() => gateway.declineInvitation(inv.roomId));

  Future<void> cancelJoinRequest() => _run(gateway.cancelJoinRequest);

  @override
  void dispose() {
    _disposed = true;
    pendingInvite.removeListener(_onPending);
    super.dispose();
  }
}
