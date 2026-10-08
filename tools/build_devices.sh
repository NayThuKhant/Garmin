#!/bin/sh
# Build every face for every device it supports (faces/<Dir>/face.json) and check device fit.
#   tools/build_devices.sh [Face ...]   (default: all faces/*Face)
# Devices whose files aren't installed (SDK Manager > Devices) are reported as MISSING.
# Per device it also checks: vector fonts used by Gfx.mc present, watch-face memory limit,
# resolution (layout scales from 390), and launcher icon size.
cd "$(dirname "$0")/.." || exit 1
. tools/ciq_env.sh
[ $# -eq 0 ] && set -- faces/*Face
for d in "$@"; do
  d=${d%/}; d=faces/${d#faces/}
  ids=$(ciq_face_devices "$d")
  mkdir -p "$d/bin/devices"
  for id in $ids; do
    if [ ! -f "$CIQ_DEVICES/$id/compiler.json" ]; then
      echo "MISSING $d $id (device files not installed)"; continue
    fi
    log="$d/bin/devices/$id.log"
    if (cd "$d" && java -Djava.awt.headless=true -jar "$SDK/bin/monkeybrains.jar" -o "bin/devices/$id.prg" -f monkey.jungle \
          -y ../../developer_key -d "$id" -w -r > "bin/devices/$id.log" 2>&1); then
      res="OK"
    else
      res="FAIL"
    fi
    notes=$(python3 - "$CIQ_DEVICES/$id" "$d/bin/devices/$id.prg" <<'PY'
import json, os, sys
dev, prg = sys.argv[1], sys.argv[2]
c = json.load(open(os.path.join(dev, "compiler.json")))
s = json.load(open(os.path.join(dev, "simulator.json")))
notes = []
r = c.get("resolution", {})
notes.append(f'{r.get("width")}x{r.get("height")}')
if c.get("displayType") != "amoled": notes.append(f'display={c.get("displayType")}')
if not str(c.get("deviceFamily", "")).startswith("round"): notes.append(f'shape={c.get("deviceFamily")}')
mem = next((a["memoryLimit"] for a in c.get("appTypes", []) if a["type"] == "watchFace"), None)
notes.append(f"mem={mem // 1024 if mem else '?'}K")
ttf = {f["name"] for fs in s.get("fonts", []) for f in fs.get("fonts", []) if f.get("type") == "system_ttf"}
for need in ("RobotoCondensedBold", "RobotoCondensedRegular", "RobotoRegular"):
    if need not in ttf: notes.append(f"no-font:{need}")
ic = c.get("launcherIcon", {})
if ic and ic.get("width") != 54: notes.append(f'icon={ic.get("width")}px(scaled)')
print(" ".join(notes))
PY
)
    echo "$res $d $id $notes"
    [ "$res" = FAIL ] && grep ERROR "$log" | head -3 | sed 's/^/      /'
  done
done
