#!/bin/sh
# Write each face's device list (faces/<Dir>/face.json "devices", the faces <-> devices map) into its
# manifest.xml products. A face without face.json gets one listing every device in tools/devices.txt.
#   tools/set_products.sh [--check] [Face ...]   (default: all faces/*Face)
#   --check: change nothing, exit 1 if a manifest doesn't match its face.json (CI).
cd "$(dirname "$0")/.." || exit 1
check=""
[ "$1" = "--check" ] && { check=1; shift; }
[ $# -eq 0 ] && set -- faces/*Face
status=0
for d in "$@"; do
  d=${d%/}; d=faces/${d#faces/}; m="$d/manifest.xml"
  [ -f "$m" ] || { echo "skip $d (no manifest)"; continue; }
  python3 - "$d" "$check" <<'PY' || status=1
import json, os, re, sys
d, check = sys.argv[1], sys.argv[2]
fj, m = os.path.join(d, "face.json"), os.path.join(d, "manifest.xml")
if not os.path.exists(fj):
    if check: sys.exit(print(f"MISSING {fj}") or 1)
    ids = [l.split("#")[0].strip() for l in open("tools/devices.txt")]
    json.dump({"devices": [i for i in ids if i]}, open(fj, "w"), indent=1); open(fj, "a").write("\n")
ids = json.load(open(fj))["devices"]
known = {l.split("#")[0].strip() for l in open("tools/devices.txt")}
for i in ids:
    if i not in known: print(f"warning: {fj}: {i} is not in tools/devices.txt")
t = open(m).read()
block = "<iq:products>\n" + "".join(f'            <iq:product id="{i}"/>\n' for i in ids) + "        </iq:products>"
new = re.sub(r"<iq:products>.*?</iq:products>", block, t, flags=re.S)
if check:
    if new != t: sys.exit(print(f"STALE {m} (run tools/set_products.sh {os.path.basename(d)})") or 1)
else:
    open(m, "w").write(new)
    print(f"set {len(ids)} products in {m}")
PY
done
exit $status
