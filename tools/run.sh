#!/bin/sh
# Build a face and run it in the simulator, with its settings available in
# File > Edit Persistent Storage / App Settings Editor.
#   tools/run.sh [Face] [device]   — anything left out is picked from a list (Enter = default);
#   the device list only shows the devices the face supports (faces/<Dir>/face.json).
cd "$(dirname "$0")/.." || exit 1
. tools/ciq_env.sh
face=${1%/}
if [ -z "$face" ]; then
  ciq_interactive || { echo "usage: tools/run.sh Face [device]" >&2; exit 1; }
  face=$(ciq_faces | ciq_pick "Face" MeridianFace) || exit 1
fi
d=faces/${face#faces/}; name=$(basename "$d")
dev=$(ciq_device "$2" "$name") || exit 1   # only devices in its face.json
tools/build.sh -d "$dev" "$name" || exit 1
pgrep -f ConnectIQ.app >/dev/null || { "$SDK/bin/connectiq" >/dev/null 2>&1 & sleep 5; }
# The simulator's App Settings Editor reads <APP>-settings.json from its GARMIN/Settings folder.
SIMDIR="${TMPDIR%/}/com.garmin.connectiq/GARMIN/Settings"
if [ -f "$d/bin/$name-settings.json" ]; then
  mkdir -p "$SIMDIR"
  cp "$d/bin/$name-settings.json" "$SIMDIR/$(echo "$name" | tr '[:lower:]' '[:upper:]')-settings.json"
fi
"$SDK/bin/monkeydo" "$d/bin/$name.prg" "$dev" >/dev/null 2>&1 &
echo "running $name on $dev"
