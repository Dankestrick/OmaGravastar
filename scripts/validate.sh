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

# Every Text item must say how to render its text. Qt's default (AutoText)
# renders anything that looks like HTML, and macro names come from the
# mouse's memory, so that could make the shell load remote images.
python3 - "$ROOT/qml" <<'PY'
import pathlib, re, sys
bad = []
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.qml")):
    lines = path.read_text().split("\n")
    for i, line in enumerate(lines):
        if not re.match(r"^\s*Text\s*\{\s*$", line):
            continue
        depth, j, has = 1, i + 1, False
        while j < len(lines) and depth > 0:
            if depth == 1 and re.match(r"^\s*textFormat\s*:", lines[j]):
                has = True
            depth += lines[j].count("{") - lines[j].count("}")
            j += 1
        if not has:
            bad.append(f"{path.name}:{i + 1}")
if bad:
    sys.exit("Text items without textFormat: " + ", ".join(bad))
print("every Text item sets textFormat")
PY

python3 -m py_compile "$ROOT/helpers/omagravastarctl"
rm -rf "$ROOT/helpers/__pycache__"
echo "helper syntax ok"

if find "$ROOT" -path "$ROOT/.git" -prune -o -type l -print | grep -q .; then
  echo "symlinks found in the plugin tree" >&2
  exit 1
fi
echo "no symlinks"
