#!/bin/sh
# Package a face for the Connect IQ Store (beta or public): tools/export.sh MeridianFace -> dist/<Face>.iq
# Upload the .iq at https://apps.garmin.com/developer/ (Upload an App -> tick "Beta App" for a private beta).
cd "$(dirname "$0")/.." || exit 1
d=${1%/}; d=faces/${d#faces/}; name=$(basename "$d")
. tools/ciq_env.sh
mkdir -p dist
(cd "$d" && java -Djava.awt.headless=true -jar "$SDK/bin/monkeybrains.jar" -e -r -w \
   -o "../../dist/$name.iq" -f monkey.jungle -y ../../developer_key) > "dist/$name-export.log" 2>&1 \
  && echo "OK    dist/$name.iq ($(du -h "dist/$name.iq" | cut -f1))" \
  || { echo "FAIL  see dist/$name-export.log"; grep -i error "dist/$name-export.log" | head -5; exit 1; }
