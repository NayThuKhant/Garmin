#!/usr/bin/env python3
"""Bundle every mockup in mockups/ into one self-contained faces.html (open it in a browser).

Usage: python3 tools/build_gallery.py   -> writes faces.html at the repo root

Faces are listed in mockups/canvas.json order, active + always-on side by side. Each mockup's
markup ({{holes}}) and its renderVals() script are embedded and evaluated in the page, with the
props' defaults.

Settings come from the face's CODE (faces/<Name>Face/resources/properties/properties.xml + strings,
and the native editor's watchface.xml), so the page always shows what the watch really offers:
  - color settings (AccentColor -> mockup prop "accent", SecondaryColor -> "secondary") become
    swatches that re-render the mockup with that color;
  - every setting is listed in a "Settings" panel (phone settings, on-watch editor, on-watch menu).
CI fails if faces.html is out of date (rerun this script after any face/mockup change).
"""
import json, os, re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOCK = os.path.join(ROOT, "mockups")


def parse(path):
    src = open(path).read()
    body = src.split("</helmet>", 1)[1].split("</x-dc>", 1)[0].strip()
    m = re.search(r"data-props='(.*?)'>(.*?)</script>", src, re.S)
    props = json.loads(m.group(1)) if m else {}
    script = m.group(2).strip() if m else "class Component extends DCLogic { renderVals() { return {}; } }"
    fonts = re.findall(r'<link rel="stylesheet" href="(https://fonts.googleapis.com/[^"]+)"', src)
    return body, props, script, fonts


FACES = os.path.join(ROOT, "faces")
PROP_FOR = {"AccentColor": "accent", "SecondaryColor": "secondary"}   # code color setting -> mockup prop
# Non-color code settings driven by a mockup color prop, matched option-by-option (same order):
INDEX_PROP = {"Theme": "accent"}


def face_dir(mockup_file):
    """mockups/Tide.dc.html / TideAOD.dc.html -> faces/TideFace (Main/RingAOD -> RingFace)."""
    name = mockup_file.replace(".dc.html", "")
    name = name[:-3] if name.endswith("AOD") else name
    name = "Ring" if name == "Main" else name
    d = os.path.join(FACES, name + "Face")
    return d if os.path.isdir(d) else None


def strings_of(d):
    out = {}
    p = os.path.join(d, "resources", "strings", "strings.xml")
    if os.path.exists(p):
        for s in ET.parse(p).getroot().iter("string"):
            out[s.get("id")] = "".join(s.itertext())
    return out


def settings_of(d):
    """Settings exactly as the face's code defines them."""
    res = {"groups": [], "native": None, "menu": False}
    strings = strings_of(d)
    lab = lambda v: strings.get(v[len("@Strings."):], v) if v and v.startswith("@Strings.") else (v or "")
    p = os.path.join(d, "resources", "properties", "properties.xml")
    if os.path.exists(p):
        root = ET.parse(p).getroot()
        defaults = {pr.get("id"): (pr.text or "").strip() for pr in root.iter("property")}
        sets = root.find("settings")
        if sets is not None:
            def item(s):
                key = s.get("propertyKey", "").replace("@Properties.", "")
                cfg = s.find("settingConfig")
                typ = cfg.get("type") if cfg is not None else "?"
                opts = [{"label": lab("".join(e.itertext()).strip()), "value": e.get("value")}
                        for e in (cfg.findall("listEntry") if cfg is not None else [])]
                d0 = defaults.get(key, "")
                dl = next((o["label"] for o in opts if o["value"] == d0), "On" if d0 == "true" else "Off" if d0 == "false" else d0)
                return {"key": key, "title": lab(s.get("title")), "type": typ, "options": opts, "default": dl}
            groups = sets.findall("group")
            if groups:
                for g in groups:
                    res["groups"].append({"title": lab(g.get("title")), "items": [item(s) for s in g.findall("setting")]})
            else:
                res["groups"].append({"title": "", "items": [item(s) for s in sets.findall("setting")]})
    for wf in (os.path.join(d, "resources-wfconfig", "configs", "watchface.xml"), os.path.join(d, "resources", "configs", "watchface.xml")):
        if os.path.exists(wf):
            r = ET.parse(wf).getroot().find("watchface-config")
            styles = [lab(s.get("label")) for s in r.iter("style")]
            dcol = [lab(c.get("label")) for c in r.iter("color")] if r.find("dataColors") is not None else []
            acc = r.find("accentColors")
            res["native"] = {"styles": styles, "dataColors": dcol,
                             "accentAny": acc is not None and acc.get("allowAny") == "true",
                             "fields": len(r.findall("data/complication"))}
            break
    src = "".join(open(os.path.join(d, "source", f)).read() for f in os.listdir(os.path.join(d, "source")) if f.endswith(".mc"))
    res["menu"] = "function getSettingsView" in src
    return res


def swatches_of(settings, mock_props):
    rows = []
    for g in settings["groups"]:
        for it in g["items"]:
            prop = INDEX_PROP.get(it["key"])
            mp = mock_props.get(prop) if prop else None
            if mp and mp.get("options") and len(mp["options"]) == len(it["options"]):
                rows.append({"prop": prop, "title": it["title"],
                             "options": [{"color": c, "label": o["label"]} for c, o in zip(mp["options"], it["options"])]})
    for g in settings["groups"]:
        for it in g["items"]:
            prop = PROP_FOR.get(it["key"])
            if prop and it["type"] == "list" and it["options"]:
                rows.append({"prop": prop, "title": it["title"],
                             "options": [{"color": "#%06X" % (int(o["value"]) & 0xFFFFFF), "label": o["label"]}
                                         for o in it["options"] if o["value"].lstrip("-").isdigit() and int(o["value"]) >= 0]})
    return rows


def main():
    canvas = json.load(open(os.path.join(MOCK, "canvas.json")))
    faces, fonts = [], []
    for name in canvas["order"]:
        b = canvas["boards"][name]
        title = b.get("title", name)
        base, _, mode = title.partition(" — ")
        body, props, script, f = parse(os.path.join(MOCK, name))
        for u in f:
            if u not in fonts:
                fonts.append(u.replace("&amp;", "&"))
        entry = next((x for x in faces if x["title"] == base), None)
        if entry is None:
            entry = {"title": base, "boards": [], "settings": None, "swatches": []}
            d = face_dir(name)
            if d:
                entry["dir"] = os.path.relpath(d, ROOT)
                entry["settings"] = settings_of(d)
                entry["swatches"] = swatches_of(entry["settings"], props)
            faces.append(entry)
        entry["boards"].append({"mode": mode or "active", "file": name, "html": body,
                                "props": {k: v for k, v in props.items() if not k.startswith("$")},
                                "script": script})
    data = json.dumps(faces, ensure_ascii=False).replace("</", "<\\/")
    links = "\n".join(f'<link rel="stylesheet" href="{u.replace("&", "&amp;")}">' for u in dict.fromkeys(fonts))
    html = PAGE.replace("{{LINKS}}", links).replace("{{DATA}}", data).replace("{{COUNT}}", str(len(faces)))
    out = os.path.join(ROOT, "faces.html")
    open(out, "w").write(html)
    print(f"wrote {out}: {len(faces)} faces")


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Watch Faces</title>
{{LINKS}}
<style>
:root { --bg: #111; --card: #191919; --text: #eee; --muted: #8a8a8a; --line: #262626; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 14px/1.4 -apple-system, "Helvetica Neue", sans-serif; }
header { padding: 28px 24px 8px; max-width: 1400px; margin: 0 auto; display: flex; flex-wrap: wrap; gap: 12px 24px; align-items: baseline; }
h1 { margin: 0; font-size: 22px; font-weight: 600; }
header p { margin: 0; color: var(--muted); }
.controls { margin-left: auto; display: flex; gap: 8px; align-items: center; color: var(--muted); }
.controls button { background: var(--card); color: var(--text); border: 1px solid var(--line); border-radius: 8px; padding: 6px 10px; font: inherit; cursor: pointer; }
.controls button[aria-pressed="true"] { border-color: #888; }
main { max-width: 1400px; margin: 0 auto; padding: 16px 24px 48px; display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 420px), 1fr)); gap: 20px; }
.face { background: var(--card); border: 1px solid var(--line); border-radius: 16px; padding: 16px; }
.face h2 { margin: 0 0 12px; font-size: 15px; font-weight: 600; display: flex; justify-content: space-between; gap: 8px; }
.face h2 small { color: var(--muted); font-weight: 400; }
.pair { display: flex; gap: 12px; }
.board { flex: 1; min-width: 0; text-align: center; color: var(--muted); font-size: 12px; }
.screen { width: 100%; aspect-ratio: 1; position: relative; }
.screen > .inner { position: absolute; left: 0; top: 0; width: 390px; height: 390px; transform-origin: 0 0; }
.swatches { display: flex; gap: 10px; align-items: center; margin-top: 10px; font-size: 12px; color: var(--muted); }
.swatches > span { min-width: 72px; }
.swatches > div { display: flex; gap: 6px; flex-wrap: wrap; }
.settings { margin-top: 12px; border-top: 1px solid var(--line); padding-top: 8px; font-size: 12px; color: var(--muted); }
.settings > summary { cursor: pointer; color: var(--text); }
.settings h3 { margin: 12px 0 4px; font-size: 12px; color: var(--text); font-weight: 600; }
.settings dl { margin: 0; display: grid; grid-template-columns: minmax(90px, 34%) 1fr; gap: 6px 10px; }
.settings dt { color: var(--text); }
.settings dd { margin: 0; display: flex; flex-wrap: wrap; gap: 4px; }
.settings .more { width: 100%; }
.settings .more > summary { cursor: pointer; }
.settings .more[open] { display: flex; flex-wrap: wrap; gap: 4px; }
.settings .more[open] > summary { width: 100%; }
.chip { border: 1px solid var(--line); border-radius: 999px; padding: 1px 8px; white-space: nowrap; }
.chip.on { border-color: #888; color: var(--text); }
.settings .note { margin: 10px 0 0; }
.swatches button { width: 20px; height: 20px; border-radius: 50%; border: 2px solid transparent; cursor: pointer; padding: 0; }
.swatches button[aria-pressed="true"] { border-color: #fff; }
body.only-active .board.aod, body.only-aod .board.active { display: none; }
</style>
</head>
<body>
<header>
  <h1>Watch faces</h1>
  <p>{{COUNT}} faces · active + always-on · 390 × 390</p>
  <div class="controls" role="group" aria-label="Show">
    <button type="button" data-show="both" aria-pressed="true">Both</button>
    <button type="button" data-show="active" aria-pressed="false">Active</button>
    <button type="button" data-show="aod" aria-pressed="false">Always-on</button>
  </div>
</header>
<main id="grid"></main>
<script id="faces-data" type="application/json">{{DATA}}</script>
<script>
class DCLogic { constructor(props) { this.props = props || {}; } }
const faces = JSON.parse(document.getElementById('faces-data').textContent);
const grid = document.getElementById('grid');

function lookup(vals, path) {
  return path.split('.').reduce((o, k) => (o == null ? o : o[k]), vals);
}
function render(board, overrides) {
  const props = {};
  for (const [k, v] of Object.entries(board.props)) props[k] = v && v.default !== undefined ? v.default : v;
  Object.assign(props, overrides);
  let vals = {};
  try {
    const Component = new Function('DCLogic', board.script + '\\nreturn Component;')(DCLogic);
    vals = new Component(props).renderVals() || {};
  } catch (e) { console.error(board.file, e); }
  return board.html.replace(/{{\\s*([\\w.]+)\\s*}}/g, (m, p) => { const v = lookup(vals, p); return v == null ? '' : v; });
}
function fit(el) {
  const s = el.parentElement.clientWidth / 390;
  el.style.transform = 'scale(' + s + ')';
}
function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}
// Every setting the face's code defines: phone settings, on-watch editor, on-watch menu.
function settingsPanel(face) {
  const s = face.settings;
  const d = el('details', 'settings');
  const n = s ? s.groups.reduce((a, g) => a + g.items.length, 0) : 0;
  const where = [];
  if (n) where.push(n + ' phone setting' + (n > 1 ? 's' : ''));
  if (s && s.native) where.push('on-watch editor');
  if (s && s.menu) where.push('on-watch menu');
  d.appendChild(el('summary', null, where.length ? 'Settings · ' + where.join(' · ') : 'No settings (fixed design)'));
  if (!s) return d;
  for (const g of s.groups) {
    if (g.title) d.appendChild(el('h3', null, g.title));
    const dl = el('dl');
    for (const it of g.items) {
      dl.appendChild(el('dt', null, it.title));
      const dd = el('dd');
      if (it.type === 'boolean') {
        dd.appendChild(el('span', 'def', 'On / Off · default ' + it.default));
      } else if (it.options.length <= 12) {
        for (const o of it.options) dd.appendChild(el('span', 'chip' + (o.label === it.default ? ' on' : ''), o.label));
      } else {
        const more = el('details', 'more');
        more.appendChild(el('summary', null, it.options.length + ' options · default ' + it.default));
        for (const o of it.options) more.appendChild(el('span', 'chip' + (o.label === it.default ? ' on' : ''), o.label));
        dd.appendChild(more);
      }
      dl.appendChild(dd);
    }
    d.appendChild(dl);
  }
  if (s.native) {
    d.appendChild(el('h3', null, 'On-watch editor (Watch Face → Customize)'));
    const dl = el('dl');
    dl.appendChild(el('dt', null, 'Style'));
    const st = el('dd'); const more = el('details', 'more');
    more.appendChild(el('summary', null, s.native.styles.length + ' styles'));
    for (const x of s.native.styles) more.appendChild(el('span', 'chip', x));
    st.appendChild(more); dl.appendChild(st);
    if (s.native.accentAny) { dl.appendChild(el('dt', null, 'Accent color')); dl.appendChild(el('dd', null, 'any color (color picker)')); }
    if (s.native.dataColors.length) {
      dl.appendChild(el('dt', null, 'Data color'));
      const dd = el('dd'); for (const x of s.native.dataColors) dd.appendChild(el('span', 'chip', x)); dl.appendChild(dd);
    }
    if (s.native.fields) { dl.appendChild(el('dt', null, 'Data fields')); dl.appendChild(el('dd', null, s.native.fields + ' fields, any Garmin complication')); }
    d.appendChild(dl);
  }
  if (s.menu) d.appendChild(el('p', 'note', 'Watches without the editor (vívoactive 5, Venu 2/3, FR 165/265/965, epix 2, …) get the same phone settings as an on-watch menu.'));
  return d;
}
const inners = [];
for (const face of faces) {
  const card = document.createElement('section');
  card.className = 'face';
  const h = document.createElement('h2');
  h.textContent = face.title;
  card.appendChild(h);
  const pair = document.createElement('div');
  pair.className = 'pair';
  const accent = face.boards.find(b => b.props.accent);
  const state = {};
  const draw = [];
  for (const b of face.boards) {
    const box = document.createElement('div');
    const aod = /always/i.test(b.mode);
    box.className = 'board ' + (aod ? 'aod' : 'active');
    const screen = document.createElement('div');
    screen.className = 'screen';
    const inner = document.createElement('div');
    inner.className = 'inner';
    screen.appendChild(inner);
    box.appendChild(screen);
    const cap = document.createElement('div');
    cap.textContent = aod ? 'always-on' : 'active';
    box.appendChild(cap);
    pair.appendChild(box);
    inners.push(inner);
    draw.push(() => { inner.innerHTML = render(b, state); });
  }
  card.appendChild(pair);
  // Color swatches = the face's real color settings (from its code), applied to the mockup.
  for (const row of face.swatches || []) {
    const wrap = document.createElement('div');
    wrap.className = 'swatches';
    const lbl = document.createElement('span');
    lbl.textContent = row.title;
    wrap.appendChild(lbl);
    const grp = document.createElement('div');
    grp.setAttribute('role', 'group');
    grp.setAttribute('aria-label', face.title + ' ' + row.title);
    const mp = (face.boards.find(b => b.props[row.prop]) || {props: {}}).props[row.prop];
    const def = mp && mp.default ? String(mp.default).toUpperCase() : (row.options[0] || {}).color;
    for (const o of row.options) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.style.background = o.color;
      btn.title = o.label;
      btn.setAttribute('aria-label', row.title + ' ' + o.label);
      btn.setAttribute('aria-pressed', o.color.toUpperCase() === def ? 'true' : 'false');
      btn.addEventListener('click', () => {
        state[row.prop] = o.color;
        grp.querySelectorAll('button').forEach(x => x.setAttribute('aria-pressed', x === btn ? 'true' : 'false'));
        draw.forEach(f => f());
      });
      grp.appendChild(btn);
    }
    wrap.appendChild(grp);
    card.appendChild(wrap);
  }
  card.appendChild(settingsPanel(face));
  draw.forEach(f => f());
  grid.appendChild(card);
}
const refit = () => inners.forEach(fit);
new ResizeObserver(refit).observe(grid);
refit();
document.querySelectorAll('.controls button').forEach(btn => btn.addEventListener('click', () => {
  document.querySelectorAll('.controls button').forEach(x => x.setAttribute('aria-pressed', x === btn ? 'true' : 'false'));
  document.body.classList.toggle('only-active', btn.dataset.show === 'active');
  document.body.classList.toggle('only-aod', btn.dataset.show === 'aod');
  refit();
}));
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
