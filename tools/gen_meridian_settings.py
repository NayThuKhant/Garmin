# Generates faces/MeridianFace/resources/{properties,strings,configs} for AE · Meridian.
import os, sys
D = sys.argv[1]
OPTS = ["None", "Steps", "Steps % of goal", "Distance", "Calories", "Intensity minutes (week)",
        "Heart rate", "Resting heart rate", "Body Battery", "Stress", "Pulse Ox (SpO2)", "Respiration",
        "Battery %", "Battery days left", "Temperature", "Weather (condition + temp)", "High / low temp",
        "Precipitation chance", "Humidity", "Wind speed", "UV index", "Sunrise", "Sunset", "Next sunrise/sunset",
        "Notifications", "Alarms", "Phone connection", "Date", "Week number", "Altitude", "Recovery time",
        "Training status", "VO2 max (run)", "Sleep score", "Next calendar event", "Floors climbed",
        "Sea level pressure"]
SOLIDS = [("White", 0xFFFFFF), ("Cream", 0xF4EEE3), ("Silver", 0xBDBDBD), ("Grey", 0x8A8A8A),
          ("Dark grey", 0x4A4A4A), ("Lime", 0xC6F432), ("Green", 0x5BE15B), ("Mint", 0x6EE7B7),
          ("Teal", 0x2DD4BF), ("Sky", 0xA9D3FF), ("Blue", 0x4DA3FF), ("Steel blue", 0x7FAEE0),
          ("Lavender", 0xB9B4F5), ("Pink", 0xFF3DA5), ("Coral", 0xFF7A6B), ("Peach", 0xF5C6A5),
          ("Orange", 0xFFA62B), ("Gold", 0xFFC21A), ("Yellow", 0xFFE11A), ("Red", 0xFF3B4E),
          ("Brick red", 0xB3412E), ("Deep teal", 0x1F4E5F), ("Navy", 0x1B2A44), ("Black", 0x111111)]
GRADS = [("Gradient white to silver", -2), ("Gradient lime to teal", -3), ("Gradient lime to pale green", -4),
         ("Gradient lime to sky", -5), ("Gradient pink to orange", -6), ("Gradient sky to lavender", -7),
         ("Gradient gold to red", -8), ("Gradient teal to blue", -9)]
strings, props, settings = {}, [], []
MENU = []          # [(group title, [(key, title, [(label, value)] or None)])]
_cur = []

def sid(name):
    return "".join(ch for ch in name.title() if ch.isalnum())

class E(str):
    """A listEntry line that also remembers its label/value for the on-watch menu."""

def entry(prefix, name, val):
    k = prefix + sid(name)
    strings[k] = name
    e = E(f'                <listEntry value="{val}">@Strings.{k}</listEntry>')
    e.label, e.value = name, val
    return e

def setting(key, title, entries, default, typ="number"):
    props.append(f'        <property id="{key}" type="{typ}">{default}</property>')
    strings["T" + key] = title
    _cur.append((key, title, None if entries is None else [(e.label, e.value) for e in entries]))
    if entries is None:
        return (f'        <setting propertyKey="@Properties.{key}" title="@Strings.T{key}">\n'
                f'            <settingConfig type="boolean"/>\n        </setting>')
    return (f'        <setting propertyKey="@Properties.{key}" title="@Strings.T{key}">\n'
            f'            <settingConfig type="list">\n' + "\n".join(entries) +
            '\n            </settingConfig>\n        </setting>')

def group(gid, title, items):
    strings["G" + gid] = title
    MENU.append((title, list(_cur))); _cur.clear()
    settings.append(f'    <group id="{gid}" title="@Strings.G{gid}">\n' + "\n".join(items) + '\n    </group>')

data = [entry("D", n, i) for i, n in enumerate(OPTS)]
group("Data", "Data fields", [
    setting("SlotTop", "Top circle", data, 34), setting("SlotLeft", "Left circle", data, 21),
    setting("SlotRight", "Right circle", data, 27), setting("SlotBottom", "Bottom circle", data, 24),
    setting("ArcTL", "Top-left arc", data, 1), setting("ArcTR", "Top-right arc", data, 13),
    setting("ArcBL", "Bottom-left arc", data, 15), setting("ArcBR", "Bottom-right arc", data, 6)])
group("Style", "Style", [
    setting("Theme", "Background", [entry("B", n, i) for i, n in enumerate(["Black", "Navy", "Charcoal", "Cream", "White"])], 0),
    setting("FontStyle", "Time font", [entry("F", n, i) for i, n in enumerate(["Rounded", "Square", "Serif", "Classic"])], 0),
    setting("Frame", "Data field frame", [entry("R", n, i) for i, n in enumerate(["Circle", "Hexagon", "None"])], 0),
    setting("TimeFormat", "Time format", [entry("H", n, i) for i, n in enumerate(["Follow watch", "12-hour", "24-hour"])], 0),
    setting("LeadingZero", "Leading zero on hour", None, "true", "boolean")])
auto = entry("C", "Auto (theme)", -1)
solid = [entry("C", n, v) for n, v in SOLIDS]
grad = [entry("C", n, v) for n, v in GRADS]
dyn = entry("C", "Dynamic (follows value)", -10)
group("TimeColors", "Time colors", [
    setting("HourColor", "Hour color", [auto] + solid + grad, -1),
    setting("MinuteColor", "Minute color", [auto] + solid + grad, -1)])
group("Colors", "Colors", [
    setting("WeekdayColor", "Weekday / label color", [auto] + solid, -1),
    setting("TextColor", "Data text color", [auto] + solid, -1),
    setting("IconColor", "Circle icon color", [auto, dyn] + solid, -1),
    setting("OutlineColor", "Data field frame color", [auto] + solid, -1),
    setting("TrackColor", "Arc track color", [auto] + solid, -1)])
group("ArcColors", "Arc colors", [
    setting("ArcColorTL", "Top-left arc color", [auto, dyn] + solid, -1),
    setting("ArcColorTR", "Top-right arc color", [auto, dyn] + solid, -1),
    setting("ArcColorBL", "Bottom-left arc color", [auto, dyn] + solid, -1),
    setting("ArcColorBR", "Bottom-right arc color", [auto, dyn] + solid, -1)])

# ---- native watch-face editor (WatchFaceConfig, API 5.1+): resources-wfconfig/configs/watchface.xml ----
# Style id = 1 + theme * 12 + font * 3 + frame (source/MeridianNative.mc decodes it). Style 0 "Phone app" is the
# default and keeps the phone's Background/Time font settings: getSettings() always returns the default
# style, so a real style as default would silently override the phone settings.
# Data color White is the default and means "auto" (theme text color / phone setting), for the same reason.
THEMES = ["Black", "Navy", "Charcoal", "Cream", "White"]
FONTS = ["Rounded", "Square", "Serif", "Classic"]
DATA_COLORS = ["White", "Cream", "Silver", "Grey", "Lime", "Sky", "Peach", "Gold"]
# uniqueIdentifier 1..8 = these slots. Every slot is allowAny (any system or Connect IQ complication).
# The SDK forbids <type default> together with allowAny, so the default is not declared here: while a
# slot has no complication chosen in the editor (complicationId null) the face shows the phone
# setting, whose defaults are these types (kept here for reference / NATIVE_TYPED below).
NATIVE_TYPED = False   # True: restrict each slot to a type list with these defaults instead of allowAny
NATIVE_SLOTS = [("SlotTop", "CALENDAR_EVENTS"), ("SlotLeft", "SUNRISE"), ("SlotRight", "WEEKDAY_MONTHDAY"),
                ("SlotBottom", "NOTIFICATION_COUNT"), ("ArcTL", "STEPS"), ("ArcTR", "BATTERY"),
                ("ArcBL", "CURRENT_WEATHER"), ("ArcBR", "HEART_RATE")]
wf = ['<resources>', '    <watchface-config>', '        <styles>']
strings["WS0"] = "Phone app"
wf.append('            <style id="0" label="@Strings.WS0" default="true"/>')
FRAMES = ["Circle", "Hexagon", "No frame"]
for t, tn in enumerate(THEMES):
    for f, fn in enumerate(FONTS):
        for r, rn in enumerate(FRAMES):
            sid_ = 1 + t * 12 + f * 3 + r
            strings[f"WS{sid_}"] = f"{tn} · {fn} · {rn}"
            wf.append(f'            <style id="{sid_}" label="@Strings.WS{sid_}"' + '/>')
wf += ['        </styles>', '        <accentColors allowAny="true"/>', '        <data>']
NATIVE_TYPES = ["BATTERY", "STEPS", "CALORIES", "FLOORS_CLIMBED", "INTENSITY_MINUTES", "WEEKDAY_MONTHDAY",
                "CURRENT_WEATHER", "CALENDAR_EVENTS", "SUNRISE", "SUNSET", "ALTITUDE", "SEA_LEVEL_PRESSURE",
                "NOTIFICATION_COUNT", "HEART_RATE", "RECOVERY_TIME", "STRESS", "BODY_BATTERY", "VO2MAX_RUN",
                "TRAINING_STATUS", "PULSE_OX", "RESPIRATION_RATE", "CURRENT_TEMPERATURE",
                "HIGH_LOW_TEMPERATURE", "SLEEP_SCORE"]
for n, (key, typ) in enumerate(NATIVE_SLOTS, 1):
    if not NATIVE_TYPED:
        wf.append(f'            <complication id="{n}" allowAny="true"/>')
        continue
    wf.append(f'            <complication id="{n}">')
    for t in NATIVE_TYPES:
        wf.append(f'                <type' + (' default="true"' if t == typ else '') +
                  f'>Complications.COMPLICATION_TYPE_{t}</type>')
    wf.append('            </complication>')
wf += ['        </data>', '        <dataColors>']
cols = dict(SOLIDS)
for n in DATA_COLORS:
    strings["WC" + sid(n)] = "White (auto)" if n == "White" else n
    wf.append(f'            <color label="@Strings.WC{sid(n)}"' + (' default="true"' if n == "White" else '') +
              f'>0x{cols[n]:06X}</color>')
wf += ['        </dataColors>', '    </watchface-config>', '</resources>', '']
os.makedirs(os.path.join(D, "resources-wfconfig/configs"), exist_ok=True)
open(os.path.join(D, "resources-wfconfig/configs/watchface.xml"), "w").write("\n".join(wf))

open(os.path.join(D, "resources/properties/properties.xml"), "w").write(
    "<resources>\n    <properties>\n" + "\n".join(props) + "\n    </properties>\n    <settings>\n" +
    "\n".join(settings) + "\n    </settings>\n</resources>\n")
open(os.path.join(D, "resources/strings/strings.xml"), "w").write(
    '<strings>\n    <string id="AppName">AE · Meridian</string>\n' +
    "\n".join(f'    <string id="{k}">{v.replace("&", "&amp;")}</string>' for k, v in strings.items()) + "\n</strings>\n")
print(len(props), "properties,", len(strings), "strings")

# ---- on-watch Customize menu data (source/MeridianMenuData.mc), same lists as the phone settings ----
def mc(s): return '"' + s.replace('"', '\\"') + '"'
lists, list_ids, out = [], {}, []
def list_id(items):
    sig = tuple(items)
    if sig not in list_ids:
        list_ids[sig] = len(lists); lists.append(items)
    return list_ids[sig]
groups = []
for gtitle, items in MENU:
    groups.append((gtitle, [(k, ti, -1 if it is None else list_id(it)) for k, ti, it in items]))
out.append("// GENERATED by tools/gen_meridian_settings.py - do not edit.")
out.append("import Toybox.Lang;\n\nmodule MenuData {\n")
out.append("    function groupTitles() as Array<String> {\n        return [" + ", ".join(mc(g) for g, _ in groups) + "];\n    }\n")
out.append("    // Per group: [key, title, list id (-1 = on/off toggle)]")
out.append("    function groupItems(g as Number) as Array<Array> {")
for gi, (_, items) in enumerate(groups):
    out.append(f"        if (g == {gi}) {{ return [" + ", ".join(f"[{mc(k)}, {mc(ti)}, {li}]" for k, ti, li in items) + "]; }")
out.append("        return [];\n    }\n")
out.append("    function labels(id as Number) as Array<String> {")
for i, it in enumerate(lists):
    out.append(f"        if (id == {i}) {{ return [" + ", ".join(mc(l) for l, _ in it) + "]; }")
out.append("        return [];\n    }\n")
out.append("    function values(id as Number) as Array<Number> {")
for i, it in enumerate(lists):
    out.append(f"        if (id == {i}) {{ return [" + ", ".join(str(v) for _, v in it) + "]; }")
out.append("        return [];\n    }\n}\n")
open(os.path.join(D, "source/MeridianMenuData.mc"), "w").write("\n".join(out))
print(len(lists), "option lists for the on-watch menu")
