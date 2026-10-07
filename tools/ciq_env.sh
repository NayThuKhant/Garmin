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
