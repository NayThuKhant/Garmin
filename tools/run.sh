#!/bin/sh
# Build a face and run it in the simulator, with its settings available in
# File > Edit Persistent Storage / App Settings Editor.   Usage: tools/run.sh MeridianFace [device]
cd "$(dirname "$0")/.." || exit 1
d=${1%/}; d=faces/${d#faces/}; name=$(basename "$d"); dev=${2:-vivoactive6}
. tools/ciq_env.sh
tools/build.sh "$name" || exit 1
pgrep -f ConnectIQ.app >/dev/null || { "$SDK/bin/connectiq" >/dev/null 2>&1 & sleep 5; }
# The simulator's App Settings Editor reads <APP>-settings.json from its GARMIN/Settings folder.
SIMDIR="${TMPDIR%/}/com.garmin.connectiq/GARMIN/Settings"
if [ -f "$d/bin/$name-settings.json" ]; then
  mkdir -p "$SIMDIR"
  cp "$d/bin/$name-settings.json" "$SIMDIR/$(echo "$name" | tr '[:lower:]' '[:upper:]')-settings.json"
fi
"$SDK/bin/monkeydo" "$d/bin/$name.prg" "$dev" >/dev/null 2>&1 &
echo "running $name on $dev"
