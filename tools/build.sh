#!/bin/sh
# Build one or more face projects: tools/build.sh SplitFace RingFace ...  (no args = all faces/*Face)
cd "$(dirname "$0")/.." || exit 1
. tools/ciq_env.sh
[ $# -eq 0 ] && set -- faces/*Face
status=0
for d in "$@"; do
  d=${d%/}; d=faces/${d#faces/}
  mkdir -p "$d/bin"
  if (cd "$d" && java -Djava.awt.headless=true -jar "$SDK/bin/monkeybrains.jar" -o "bin/$(basename "$d").prg" -f monkey.jungle -y ../../developer_key -d vivoactive6_sim -w > bin/build.log 2>&1); then
    echo "OK    $d"
  else
    echo "FAIL  $d (see $d/bin/build.log)"; tail -15 "$d/bin/build.log"; status=1
  fi
done
exit $status
