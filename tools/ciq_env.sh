# Shared SDK / device locations for the tools/*.sh scripts. Override in CI:
#   CIQ_SDK      SDK root (contains bin/monkeybrains.jar)
#   CIQ_DEVICES  folder with one sub-folder per device (compiler.json, simulator.json)
if [ -z "$CIQ_SDK" ]; then
  CIQ_SDK=$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-"*9.2.0* 2>/dev/null | head -1)
fi
if [ -z "$CIQ_DEVICES" ]; then
  for c in "$HOME/Library/Application Support/Garmin/ConnectIQ/Devices" "$HOME/.Garmin/ConnectIQ/Devices"; do
    [ -d "$c" ] && CIQ_DEVICES="$c" && break
  done
fi
SDK="$CIQ_SDK"
export CIQ_SDK CIQ_DEVICES

# ---- interactive pickers (only when stdin is a terminal; CI never prompts) ----

# ciq_devices: installed target devices from tools/devices.txt as "id<TAB>display name" lines.
ciq_devices() {
  python3 - "$CIQ_DEVICES" <<'PY'
import json, os, sys
d = sys.argv[1]
for line in open("tools/devices.txt"):
    i = line.split("#")[0].strip()
    if not i: continue
    p = os.path.join(d, i, "compiler.json")
    if os.path.exists(p):
        print(f"{i}\t{json.load(open(p)).get('displayName', i)}")
PY
}

# ciq_pick PROMPT DEFAULT < "value<TAB>label" lines  ->  prints the chosen value.
# Accepts a number from the list, an exact value, or Enter for DEFAULT.
ciq_pick() {
  _prompt=$1; _def=$2; _list=$(cat)
  printf '%s\n' "$_list" | awk -F'\t' -v def="$_def" '{ mark = ($1 == def) ? "*" : " "; printf "%3d)%s %-26s %s\n", NR, mark, $1, $2 }' >&2
  while :; do
    printf '%s [Enter = %s]: ' "$_prompt" "$_def" >&2
    read -r _ans < /dev/tty || _ans=""
    [ -z "$_ans" ] && { echo "$_def"; return; }
    _v=$(printf '%s\n' "$_list" | awk -F'\t' -v a="$_ans" '(NR == a) || ($1 == a) { print $1; exit }')
    [ -n "$_v" ] && { echo "$_v"; return; }
    echo "  not in the list: $_ans" >&2
  done
}

# ciq_device [given]: the device to use — the given one, else ask (terminal), else vivoactive6.
ciq_device() {
  if [ -n "$1" ]; then echo "$1"; return; fi
  if ciq_interactive; then ciq_devices | ciq_pick "Device" vivoactive6; else echo vivoactive6; fi
}

# ciq_faces: "FaceDir<TAB>display name" for every face (name = AppName string in its resources).
ciq_faces() {
  for f in faces/*Face; do
    n=$(sed -n 's|.*<string id="AppName">\(.*\)</string>.*|\1|p' "$f/resources/strings/strings.xml" 2>/dev/null | head -1)
    printf '%s\t%s\n' "$(basename "$f")" "$n"
  done
}

# ciq_interactive: true when we may prompt (a terminal, not CI).
ciq_interactive() { [ -t 0 ] && [ -z "$CI" ]; }
