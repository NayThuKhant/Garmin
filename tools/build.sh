#!/bin/sh
# Build face projects for the simulator.
#   tools/build.sh [-d device] [Face ...]   (faces whose face.json lacks the device are skipped)
# Left out in a terminal: pick the face (Enter = all) and the device (Enter = vivoactive6) from lists.
# Non-interactive (CI): all faces, vivoactive6.
cd "$(dirname "$0")/.." || exit 1
. tools/ciq_env.sh
dev=""
if [ "$1" = "-d" ]; then dev=$2; shift 2; fi
if [ $# -eq 0 ]; then
  if ciq_interactive; then
    pick=$( { printf 'all\tevery face\n'; ciq_faces; } | ciq_pick "Face" all) || exit 1
    [ "$pick" = all ] && set -- faces/*Face || set -- "$pick"
  else
    set -- faces/*Face
  fi
fi
# with one face, only offer the devices it supports (face.json)
[ $# -eq 1 ] && one=$1 || one=""
dev=$(ciq_device "$dev" "$one") || exit 1
status=0
for d in "$@"; do
  d=${d%/}; d=faces/${d#faces/}
  if ! ciq_supports "$d" "$dev"; then echo "SKIP  $d ($dev not in $d/face.json)"; continue; fi
  mkdir -p "$d/bin"
  if (cd "$d" && java -Djava.awt.headless=true -jar "$SDK/bin/monkeybrains.jar" -o "bin/$(basename "$d").prg" -f monkey.jungle -y ../../developer_key -d "${dev}_sim" -w > bin/build.log 2>&1); then
    echo "OK    $d ($dev)"
  else
    echo "FAIL  $d ($dev, see $d/bin/build.log)"; tail -15 "$d/bin/build.log"; status=1
  fi
done
exit $status
