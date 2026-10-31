#!/usr/bin/env bash
# Prüft vor einem Release-Build, ob der Release-Review für genau diesen Code-Stand vorliegt (Skill release-review).
# Der Bericht docs/release-reviews/<Version>.md nennt den Fingerabdruck des App-Codes. Der Fingerabdruck kommt aus den
# Blob-Hashes im Commit: Er braucht keine Git-Historie (flacher Checkout in der CI), übersteht Merge-Commits und ändert
# sich nicht durch den Bericht selbst.
#
#   tool/check_release_review.sh           Prüfung, Exit 1 ohne passenden Bericht
#   tool/check_release_review.sh --print   nur Version und Fingerabdruck von HEAD ausgeben
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Dieselbe Liste steht in .claude/skills/release-review/SKILL.md und reviewer-regeln.md.
paths=(lib android ios macos linux windows web flatpak pubspec.yaml pubspec.lock)

version=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '\r')
if [ -z "$version" ]; then
  echo "::error::Keine Version in pubspec.yaml gefunden" >&2
  exit 1
fi
fingerprint=$(git ls-tree -r -z HEAD -- "${paths[@]}" | git hash-object --stdin)

if [ "${1:-}" = "--print" ]; then
  echo "Version: $version"
  echo "Fingerabdruck: $fingerprint"
  exit 0
fi

report="docs/release-reviews/$version.md"
if [ ! -f "$report" ]; then
  echo "::error::Kein Release-Review für $version ($report fehlt). Erst /release-review ausführen und den Bericht mergen." >&2
  exit 1
fi

reviewed=$(sed -n 's/^- Fingerabdruck: *//p' "$report" | head -n 1 | tr -d '\r')
if [ "$reviewed" != "$fingerprint" ]; then
  echo "::error::Release-Review für $version passt nicht zum Code (Bericht: ${reviewed:-keiner}, Stand: $fingerprint). /release-review erneut ausführen." >&2
  exit 1
fi

echo "Release-Review für $version passt zum Code-Stand ($fingerprint)."
