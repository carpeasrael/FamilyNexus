/// Marken, die `docs/ENTSCHEIDUNGEN.md` vor der Freigabe der Kontakte (`ContactFlags.enabled`) tragen muss (#119, E-114).
const List<String> releaseMarkers = <String>['K3b-2 abgeschlossen', 'K3c Pin-Sackgasse gelöst', 'K3c abgeschlossen'];

/// Die Marken aus [releaseMarkers], die in [doc] **nicht** als eigene Zeile `MARKE: <Marke>` stehen. Eine Erwähnung im
/// Fließtext oder in Anführungszeichen zählt nicht (sonst genügte die Beschreibung der Bedingung als Erfüllung).
List<String> missingReleaseMarkers(String doc) => <String>[
      for (final m in releaseMarkers)
        if (!RegExp('^MARKE: ${RegExp.escape(m)}[ \\t]*\\r?\$', multiLine: true).hasMatch(doc)) m,
    ];
