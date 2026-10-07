#!/bin/sh
# Per-device launcher icons at each device's exact size (no scaling warnings):
#   tools/make_icons.sh [Face ...]   (default: all faces/*Face)
# Writes faces/<Face>/resources-<device>/drawables/{launcher_icon.png,drawables.xml} from faces/<Face>/icon.json.
cd "$(dirname "$0")/.." || exit 1
. tools/ciq_env.sh
D="$CIQ_DEVICES"
[ $# -eq 0 ] && set -- faces/*Face
for f in "$@"; do
  f=${f%/}; f=faces/${f#faces/}
  [ -f "$f/icon.json" ] || { echo "skip $f (no icon.json)"; continue; }
  n=0
  for id in $(grep -o 'iq:product id="[^"]*"' "$f/manifest.xml" | sed 's/.*id="//;s/"//'); do
    sz=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('launcherIcon',{}).get('width',54))" "$D/$id/compiler.json" 2>/dev/null || echo 54)
    [ "$sz" = 54 ] && continue
    mkdir -p "$f/resources-$id/drawables"
    python3 tools/icon.py "$f/resources-$id/drawables/launcher_icon.png" "$f/icon.json" "$sz"
    printf '<drawables>\n    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>\n</drawables>\n' > "$f/resources-$id/drawables/drawables.xml"
    n=$((n+1))
  done
  echo "icons: $f ($n device sizes)"
done
