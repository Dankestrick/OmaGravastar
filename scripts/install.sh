#!/usr/bin/env bash
# Developer install: copy this repo's plugin files into the live Omarchy
# plugin folder. Does not touch ~/.config/omagravastar or ~/.cache/omagravastar.
#
# It only replaces a folder that this script created and that still holds
# exactly what it put there. The marker .omagravastar-dev-install lists every
# installed file with its SHA-256. If the folder has a file that is not on
# that list, or a listed file was changed, it stops and changes nothing.
# A folder from `omarchy plugin add` (a git checkout) or anything else is
# left alone; remove it first with
# `omarchy plugin remove io.github.dankestrick.omagravastar`.
set -euo pipefail

ID="io.github.dankestrick.omagravastar"
MARKER=".omagravastar-dev-install"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
DEST="$PLUGINS/$ID"

refuse() {
  echo "Not installing: $1" >&2
  shift
  for line in "$@"; do echo "  $line" >&2; done
  echo "Nothing was changed. Move your own files out of $DEST," >&2
  echo "or remove the plugin first: omarchy plugin remove $ID" >&2
  exit 1
}

# Files the marker says this script installed: listed[relative path]=sha256.
declare -A listed=()

read_marker() {
  local line hash rel
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    hash="${line%%  *}"
    rel="${line#*  }"
    if [[ ! "$hash" =~ ^[0-9a-f]{64}$ ]] \
      || [[ ! "$rel" =~ ^(manifest\.json|(qml|helpers|udev|assets)/[A-Za-z0-9._-]+)$ ]]; then
      refuse "$DEST/$MARKER is not a file list written by this script."
    fi
    listed["$rel"]="$hash"
  done < "$DEST/$MARKER"
  [ "${#listed[@]}" -gt 0 ] || refuse "$DEST/$MARKER lists no files."
}

# Succeeds only if every entry in DEST is the marker, one of the payload
# folders, or a listed file that is byte-for-byte what was installed.
check_dest() {
  local problems=() path rel sum
  while IFS= read -r -d '' path; do
    rel="${path#"$DEST"/}"
    case "$rel" in
      "$MARKER") continue ;;
      qml|helpers|udev|assets)
        if [ -L "$path" ] || [ ! -d "$path" ]; then
          problems+=("$rel (not a plain folder)")
        fi
        continue
        ;;
    esac
    if [ -L "$path" ] || [ ! -f "$path" ]; then
      problems+=("$rel (not a regular file)")
    elif [ -z "${listed[$rel]+set}" ]; then
      problems+=("$rel (not installed by this script)")
    else
      sum="$(sha256sum -- "$path")"
      [ "${sum%% *}" = "${listed[$rel]}" ] || problems+=("$rel (changed since it was installed)")
    fi
  done < <(find "$DEST" -mindepth 1 -print0)
  if [ "${#problems[@]}" -gt 0 ]; then
    refuse "$DEST has files this script did not install or has changed:" "${problems[@]}"
  fi
}

mkdir -p "$PLUGINS"
if [ -L "$PLUGINS" ]; then
  echo "Not installing: $PLUGINS is a symlink" >&2
  exit 1
fi

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  [ -L "$DEST" ] && refuse "$DEST is a symlink."
  [ -d "$DEST" ] || refuse "$DEST is not a folder."
  [ -O "$DEST" ] || refuse "$DEST is not owned by you."
  [ -e "$DEST/.git" ] && refuse "$DEST is a git checkout (installed by omarchy plugin add)."
  if [ ! -f "$DEST/$MARKER" ] || [ -L "$DEST/$MARKER" ]; then
    refuse "$DEST was not created by scripts/install.sh."
  fi
  read_marker
  check_dest
fi

# Build the new copy next to the old one, then swap it in, so a failed
# copy never leaves a half-written plugin behind.
STAGE="$(mktemp -d "$PLUGINS/.$ID.new.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
mkdir "$STAGE/qml" "$STAGE/helpers" "$STAGE/udev"
cp "$ROOT/manifest.json" "$STAGE/manifest.json"
cp "$ROOT/qml/"*.qml "$ROOT/qml/"*.js "$STAGE/qml/"
cp "$ROOT/helpers/omagravastarctl" "$STAGE/helpers/omagravastarctl"
cp "$ROOT/udev/70-gravastar-mouse.rules" "$STAGE/udev/"
if [ -d "$ROOT/assets" ]; then
  mkdir "$STAGE/assets"
  cp "$ROOT/assets/"* "$STAGE/assets/"
fi
chmod +x "$STAGE/helpers/omagravastarctl"
{
  echo "# Created by OmaGravastar scripts/install.sh. It replaces this folder only"
  echo "# while it holds exactly these files, unchanged."
  (cd "$STAGE" && find manifest.json qml helpers udev $([ -d "$STAGE/assets" ] && echo assets) -type f -print0 | sort -z | xargs -0 sha256sum)
} > "$STAGE/$MARKER"
chmod 755 "$STAGE"

if [ -d "$DEST" ]; then
  OLD="$(mktemp -d "$PLUGINS/.$ID.old.XXXXXX")"
  mv -T "$DEST" "$OLD/plugin"
  if ! mv -T "$STAGE" "$DEST"; then
    mv -T "$OLD/plugin" "$DEST"
    rmdir "$OLD"
    exit 1
  fi
  trap - EXIT
  # The old copy was checked above to hold only the listed, unchanged files.
  # Remove exactly those, then the empty folders. Anything that appeared
  # since the check makes rmdir fail, and the old copy is kept.
  for rel in "${!listed[@]}"; do
    rm -f -- "$OLD/plugin/$rel"
  done
  rm -f -- "$OLD/plugin/$MARKER"
  for dir in qml helpers udev assets; do
    [ -d "$OLD/plugin/$dir" ] && { rmdir -- "$OLD/plugin/$dir" 2>/dev/null || true; }
  done
  if ! rmdir -- "$OLD/plugin" "$OLD" 2>/dev/null; then
    echo "Kept the previous copy at $OLD/plugin: it had new files in it." >&2
  fi
else
  mv -T "$STAGE" "$DEST"
  trap - EXIT
fi

echo "Installed to $DEST"
echo "If the service looks stale: omarchy restart shell"
