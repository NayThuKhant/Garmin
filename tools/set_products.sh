#!/bin/sh
# Write the product list from tools/devices.txt into manifest.xml of the given face dirs (default: all faces/*Face).
cd "$(dirname "$0")/.." || exit 1
[ $# -eq 0 ] && set -- faces/*Face
ids=$(sed 's/#.*//' tools/devices.txt | awk 'NF{print $1}')
for d in "$@"; do
  d=${d%/}; d=faces/${d#faces/}; m="$d/manifest.xml"
  [ -f "$m" ] || { echo "skip $d (no manifest)"; continue; }
  python3 - "$m" $ids <<'PY'
import re, sys
path, ids = sys.argv[1], sys.argv[2:]
t = open(path).read()
block = "<iq:products>\n" + "".join(f'            <iq:product id="{i}"/>\n' for i in ids) + "        </iq:products>"
t = re.sub(r"<iq:products>.*?</iq:products>", block, t, flags=re.S)
open(path, "w").write(t)
PY
  echo "set $(echo "$ids" | wc -l | tr -d ' ') products in $m"
done
