#!/usr/bin/env bash
# Remove OmaGravastar the same way the README describes.
set -euo pipefail
omarchy plugin remove io.github.dankestrick.omagravastar --yes
echo "The udev rule and ~/.cache/omagravastar are still there. See the README to remove them."
