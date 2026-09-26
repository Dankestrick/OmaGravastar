#!/usr/bin/env bash
# Run the Omarchy plugin checks: manifest validation, qmllint, helper syntax.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHELL_DIR="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
QMLLINT="$(command -v qmllint || echo /usr/lib/qt6/bin/qmllint)"

omarchy plugin validate "$ROOT"
echo "omarchy plugin validate ok"

# qmllint resolves `import qs.Ui` as qs/Ui under an import path, so point it
# at a temporary tree that mirrors the shell's modules.
IMPORTS="$(mktemp -d)"
trap 'rm -rf "$IMPORTS"' EXIT
mkdir -p "$IMPORTS/qs"
ln -s "$SHELL_DIR/Ui" "$IMPORTS/qs/Ui"
ln -s "$SHELL_DIR/Commons" "$IMPORTS/qs/Commons"
for f in "$ROOT"/qml/*.qml; do
  # Type-lookup warnings match the stock panels; only the exit code counts.
  "$QMLLINT" -I "$IMPORTS" "$f" >/dev/null 2>&1
  echo "qmllint ok: ${f#"$ROOT"/}"
done

python3 -m py_compile "$ROOT/helpers/omagravastarctl"
rm -rf "$ROOT/helpers/__pycache__"
echo "helper syntax ok"

if find "$ROOT" -path "$ROOT/.git" -prune -o -type l -print | grep -q .; then
  echo "symlinks found in the plugin tree" >&2
  exit 1
fi
echo "no symlinks"
