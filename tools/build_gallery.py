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
            # a non-color setting whose mockup prop lists a swatch color per option (Meridian's Theme)
            mp = mock_props.get(it["key"])
            if mp and mp.get("swatches") and len(mp["swatches"]) == len(it["options"]):
                rows.append({"prop": it["key"], "title": it["title"],
                             "options": [{"color": c, "label": o["label"], "value": int(o["value"])}
                                         for c, o in zip(mp["swatches"], it["options"])]})
    for g in settings["groups"]:
        for it in g["items"]:
            prop = PROP_FOR.get(it["key"])
            if prop and it["type"] == "list" and it["options"]:
                rows.append({"prop": prop, "title": it["title"],
                             "options": [{"color": "#%06X" % (int(o["value"]) & 0xFFFFFF), "label": o["label"],
                                          "value": "#%06X" % (int(o["value"]) & 0xFFFFFF)}
                                         for o in it["options"] if o["value"].lstrip("-").isdigit() and int(o["value"]) >= 0]})
    return rows


def repo_url():
    import subprocess
    try:
        u = subprocess.run(["git", "-C", ROOT, "remote", "get-url", "origin"], capture_output=True, text=True).stdout.strip()
    except Exception:
        u = ""
    u = re.sub(r"^git@github\.com:", "https://github.com/", u)
    return re.sub(r"\.git$", "", u)


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
                for g in entry["settings"]["groups"]:
                    for it in g["items"]:
                        # a setting is playable when the mockup has a prop for it: same name (value as-is)
                        # or a color prop (AccentColor -> accent, value as #RRGGBB)
                        if it["key"] in props:
                            it["prop"], it["hex"] = it["key"], False
                        elif PROP_FOR.get(it["key"]) in props:
                            it["prop"], it["hex"] = PROP_FOR[it["key"]], True
            faces.append(entry)
        entry["boards"].append({"mode": mode or "active", "file": name, "html": body,
                                "props": {k: v for k, v in props.items() if not k.startswith("$")},
                                "script": script})
    data = json.dumps(faces, ensure_ascii=False).replace("</", "<\\/")
    links = "\n".join(f'<link rel="stylesheet" href="{u.replace("&", "&amp;")}">' for u in dict.fromkeys(fonts))
    repo = repo_url()
    html = (PAGE.replace("{{LINKS}}", links).replace("{{DATA}}", data).replace("{{COUNT}}", str(len(faces)))
            .replace("{{RELEASES}}", repo + "/releases/latest" if repo else "#"))
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
main { max-width: 1600px; margin: 0 auto; padding: 12px 24px 48px; display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 290px), 1fr)); gap: 14px; }
.face[hidden] { display: none; }
.face { background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 12px; }
.face h2 { margin: 0 0 8px; font-size: 13px; font-weight: 600; display: flex; justify-content: space-between; gap: 8px; }
.face h2 small { color: var(--muted); font-weight: 400; }
.pair { display: flex; gap: 8px; }
.board { flex: 1; min-width: 0; text-align: center; color: var(--muted); font-size: 11px; }
.screen { width: 100%; aspect-ratio: 1; position: relative; }
.screen > .inner { position: absolute; left: 0; top: 0; width: 390px; height: 390px; transform-origin: 0 0; }
.swatches { display: flex; gap: 8px; align-items: center; margin-top: 8px; font-size: 11px; color: var(--muted); }
.swatches > span { min-width: 64px; }
.swatches > div { display: flex; gap: 6px; flex-wrap: wrap; }
.settings { font-size: 12px; color: var(--muted); }
.face-foot { margin-top: 10px; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; font-size: 11px; color: var(--muted); }
.settings-btn { background: var(--card); color: var(--text); border: 1px solid #3a3a3a; border-radius: 8px; padding: 4px 10px; font: inherit; cursor: pointer; }
.settings-btn:hover { border-color: #777; }
.settings-dialog { box-sizing: border-box; width: min(920px, calc(100vw - 24px)); max-height: calc(100dvh - 24px); overflow-x: hidden; overflow-wrap: anywhere; background: #161616; color: var(--text); border: 1px solid var(--line); border-radius: 16px; padding: 20px; }
.settings-dialog::backdrop { background: rgba(0,0,0,.6); }
.dlg-head { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
.dlg-head h2 { margin: 0; font-size: 17px; }
.dlg-close { background: none; border: 1px solid var(--line); color: var(--text); border-radius: 8px; width: 32px; height: 32px; cursor: pointer; font-size: 14px; }
.dlg-sub { margin: 4px 0 0; color: var(--muted); font-size: 12px; }
.dlg-body { display: grid; grid-template-columns: 300px minmax(0, 1fr); gap: 24px; margin-top: 16px; align-items: start; }
.dlg-preview .screen { width: 300px; }
.settings-dialog .settings { margin: 0; border: 0; padding: 0; }

.settings h3 { margin: 12px 0 4px; font-size: 12px; color: var(--text); font-weight: 600; }
.settings dl { margin: 0; display: grid; grid-template-columns: minmax(90px, 34%) minmax(0, 1fr); gap: 6px 10px; }
.settings dt { color: var(--text); }
.settings dd { margin: 0; display: flex; flex-wrap: wrap; gap: 4px; min-width: 0; }
.settings .more { width: 100%; }
.settings .more > summary { cursor: pointer; }
.settings .chips { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
.chip { border: 1px solid var(--line); border-radius: 999px; padding: 1px 8px; white-space: nowrap; max-width: 100%; overflow: hidden; text-overflow: ellipsis; }
.chip.on { border-color: #888; color: var(--text); }
.chip.play { background: none; color: var(--muted); font: inherit; cursor: pointer; }
.chip.play:hover { border-color: #666; color: var(--text); }
.chip.play.on { border-color: #ddd; color: var(--text); background: #2a2a2a; }
.settings .note { margin: 10px 0 0; }
.swatches button { width: 16px; height: 16px; border-radius: 50%; border: 2px solid transparent; cursor: pointer; padding: 0; }
.swatches button[aria-pressed="true"] { border-color: #fff; }
body.only-active .board.aod, body.only-aod .board.active { display: none; }
.download-btn { background: #e8e8e8; color: #111; border-radius: 8px; padding: 7px 12px; font-weight: 600; text-decoration: none; white-space: nowrap; }
.download-btn:hover { background: #fff; }
.card-btn { flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: 6px; background: var(--card); color: var(--text); border: 1px solid #3a3a3a; border-radius: 8px; padding: 6px 10px; font: inherit; font-size: 12px; cursor: pointer; text-decoration: none; }
.card-btn:hover { border-color: #777; }
.download-btn { display: inline-flex; align-items: center; gap: 6px; }
.dlg-files { margin: 8px 0 0; font-size: 12px; color: var(--muted); display: flex; flex-wrap: wrap; gap: 6px 12px; }
.dlg-files a { color: #8fc2ff; }
.search { flex: 1 1 220px; max-width: 360px; background: var(--card); color: var(--text); border: 1px solid var(--line); border-radius: 8px; padding: 7px 10px; font: inherit; }
.search:focus { outline: none; border-color: #777; }
.empty { grid-column: 1 / -1; color: var(--muted); padding: 24px 0; text-align: center; }
@media (max-width: 680px) { .dlg-body { grid-template-columns: minmax(0, 1fr); } .dlg-preview .screen { width: min(260px, 100%); margin: 0 auto; } .settings-dialog { padding: 14px; } }
@media (max-width: 480px) { .settings dl { grid-template-columns: minmax(0, 1fr); gap: 2px; } .settings dd { margin-bottom: 8px; } header { padding: 16px 12px 4px; } main { padding: 8px 12px 32px; } .controls { margin-left: 0; } .search { max-width: none; } }
</style>
</head>
<body>
<header>
  <h1>Watch faces</h1>
  <p>{{COUNT}} faces · active + always-on · 390 × 390</p>
  <input class="search" id="search" type="search" placeholder="Search faces or settings…" aria-label="Search faces">
  <a class="download-btn" href="{{RELEASES}}" target="_blank" rel="noopener"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/></svg><span>Download</span></a>
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
const RELEASES = '{{RELEASES}}';   // latest GitHub release
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
// A setting option's value as the mockup prop expects it.
function optValue(it, o) {
  if (it.hex) return '#' + (Number(o.value) & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase();
  if (o.value === 'true' || o.value === 'false') return o.value === 'true';
  return isNaN(Number(o.value)) ? o.value : Number(o.value);
}
function currentValue(face, state, prop) {
  if (state[prop] !== undefined) return state[prop];
  const b = face.boards.find(x => x.props[prop]);
  return b ? b.props[prop].default : undefined;
}
// Every setting the face's code defines: phone settings, on-watch editor, on-watch menu.
// Icons (Lucide-style strokes)
const SVG_SETTINGS = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 7h-9M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/></svg>';
const SVG_DOWNLOAD = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/></svg>';
function iconButton(tag, cls, svg, label) {
  const b = el(tag, cls);
  b.innerHTML = svg;
  b.appendChild(el('span', null, label));
  return b;
}
const openLists = new Set();   // keeps expanded option lists open while you click
function settingCount(s) { return s ? s.groups.reduce((a, g) => a + g.items.length, 0) : 0; }
function settingsSummary(face) {
  const s = face.settings, n = settingCount(s), where = [];
  if (n) where.push(n + ' phone setting' + (n > 1 ? 's' : ''));
  if (s && s.native) where.push('on-watch editor');
  if (s && s.menu) where.push('on-watch menu');
  return where.join(' · ');
}
function settingsBody(face, state, onChange) {
  const s = face.settings;
  const d = el('div', 'settings');
  if (!s || (!settingCount(s) && !s.native)) { d.appendChild(el('p', 'note', 'No settings: this face has a fixed design.')); return d; }
  for (const g of s.groups) {
    d.appendChild(el('h3', null, g.title || 'Phone settings (Connect IQ app)'));
    const dl = el('dl');
    for (const it of g.items) {
      dl.appendChild(el('dt', null, it.title));
      const dd = el('dd');
      const opts = it.type === 'boolean' ? [{label: 'On', value: 'true'}, {label: 'Off', value: 'false'}] : it.options;
      const cur = it.prop ? currentValue(face, state, it.prop) : undefined;
      const chip = o => {
        const on = it.prop ? String(optValue(it, o)).toUpperCase() === String(cur).toUpperCase() : o.label === it.default;
        if (!it.prop) return el('span', 'chip' + (on ? ' on' : ''), o.label);
        const b = el('button', 'chip play' + (on ? ' on' : ''), o.label);
        b.type = 'button';
        b.setAttribute('aria-pressed', on ? 'true' : 'false');
        b.addEventListener('click', () => { state[it.prop] = optValue(it, o); onChange(); });
        return b;
      };
      const curLabel = it.prop ? (opts.find(o => String(optValue(it, o)).toUpperCase() === String(cur).toUpperCase()) || {}).label : it.default;
      if (opts.length <= 12) {
        for (const o of opts) dd.appendChild(chip(o));
      } else {
        const more = el('details', 'more');
        more.dataset.key = it.key;
        if (openLists.has(face.title + '/' + it.key)) more.open = true;
        more.addEventListener('toggle', () => { const k = face.title + '/' + it.key; more.open ? openLists.add(k) : openLists.delete(k); });
        more.appendChild(el('summary', null, opts.length + ' options · ' + (it.prop ? (curLabel || it.default) : 'default ' + it.default)));
        const box = el('div', 'chips');
        for (const o of opts) box.appendChild(chip(o));
        more.appendChild(box);
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
    const box = el('div', 'chips');
    for (const x of s.native.styles) box.appendChild(el('span', 'chip', x));
    more.appendChild(box);
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
// Swatch rows bound to a face's state: the face's real color settings, applied to the mockup.
function swatchRows(face, state, onChange) {
  const out = [];
  for (const row of face.swatches || []) {
    const wrap = el('div', 'swatches');
    wrap.appendChild(el('span', null, row.title));
    const grp = el('div');
    grp.setAttribute('role', 'group');
    grp.setAttribute('aria-label', face.title + ' ' + row.title);
    const mp = (face.boards.find(b => b.props[row.prop]) || {props: {}}).props[row.prop];
    const cur = String(state[row.prop] !== undefined ? state[row.prop] : (mp && mp.default !== undefined ? mp.default : (row.options[0] || {}).value)).toUpperCase();
    for (const o of row.options) {
      const btn = el('button');
      btn.type = 'button';
      btn.style.background = o.color;
      btn.title = o.label;
      btn.setAttribute('aria-label', row.title + ' ' + o.label);
      btn.setAttribute('aria-pressed', String(o.value).toUpperCase() === cur ? 'true' : 'false');
      btn.addEventListener('click', () => { state[row.prop] = o.value; onChange(); });
      grp.appendChild(btn);
    }
    wrap.appendChild(grp);
    out.push(wrap);
  }
  return out;
}
// One shared popup for settings.
const dlg = el('dialog', 'settings-dialog');
dlg.setAttribute('aria-labelledby', 'dlg-title');
document.body.appendChild(dlg);
dlg.addEventListener('click', ev => { if (ev.target === dlg) dlg.close(); });
let dlgRefresh = null;
dlg.addEventListener('close', () => { dlgRefresh = null; });
function openSettings(face, state, redrawCard) {
  dlg.textContent = '';
  const head = el('div', 'dlg-head');
  const h = el('h2', null, face.title + ' — settings'); h.id = 'dlg-title';
  const x = el('button', 'dlg-close', '✕'); x.type = 'button'; x.setAttribute('aria-label', 'Close');
  x.addEventListener('click', () => dlg.close());
  head.appendChild(h); head.appendChild(x); dlg.appendChild(head);
  const sub = settingsSummary(face);
  if (sub) dlg.appendChild(el('p', 'dlg-sub', sub));
  const dir = (face.dir || '').split('/').pop();
  if (dir && RELEASES !== '#') {
    const files = el('p', 'dlg-files');
    files.appendChild(el('span', null, 'Download: '));
    const a = el('a', null, dir + '.zip');
    a.href = RELEASES.replace(/\/latest$/, '/latest/download/') + dir + '.zip';
    files.appendChild(a);
    files.appendChild(el('span', null, '(' + dir + '.iq for all devices, vivoactive6.prg, vivoactive5.prg)'));
    dlg.appendChild(files);
  }
  const body = el('div', 'dlg-body');
  const left = el('div', 'dlg-preview');
  const screen = el('div', 'screen'); const inner = el('div', 'inner');
  screen.appendChild(inner); left.appendChild(screen);
  const sw = el('div'); left.appendChild(sw);
  body.appendChild(left);
  const right = el('div');
  body.appendChild(right);
  dlg.appendChild(body);
  const active = face.boards.find(b => !/always/i.test(b.mode)) || face.boards[0];
  const change = () => { redrawCard(); refresh(); };
  const refresh = () => {
    inner.innerHTML = render(active, state);
    sw.textContent = '';
    for (const r of swatchRows(face, state, change)) sw.appendChild(r);
    const y = dlg.scrollTop;
    right.textContent = '';
    right.appendChild(settingsBody(face, state, change));
    dlg.scrollTop = y;
  };
  dlgRefresh = refresh;
  refresh();
  dlg.showModal();
  fit(inner);
}
const inners = [];
for (const face of faces) {
  const card = el('section', 'face');
  card.appendChild(el('h2', null, face.title));
  const pair = el('div', 'pair');
  const state = {};
  const draw = [];
  for (const b of face.boards) {
    const aod = /always/i.test(b.mode);
    const box = el('div', 'board ' + (aod ? 'aod' : 'active'));
    const screen = el('div', 'screen'); const inner = el('div', 'inner');
    screen.appendChild(inner); box.appendChild(screen);
    box.appendChild(el('div', null, aod ? 'always-on' : 'active'));
    pair.appendChild(box);
    inners.push(inner);
    draw.push(() => { inner.innerHTML = render(b, state); });
  }
  card.appendChild(pair);
  const redrawCard = () => {
    draw.forEach(f => f());
    if (dlgRefresh && dlg.open && dlg.dataset.face === face.title) dlgRefresh();
  };
  const foot = el('div', 'face-foot');
  const n = settingCount(face.settings);
  const btn = iconButton('button', 'card-btn', SVG_SETTINGS, n ? 'Settings (' + n + ')' : 'Settings');
  btn.type = 'button';
  btn.setAttribute('aria-label', face.title + ' settings');
  btn.addEventListener('click', () => { dlg.dataset.face = face.title; openSettings(face, state, redrawCard); });
  foot.appendChild(btn);
  const dir = (face.dir || '').split('/').pop();
  if (dir) {
    const dl = iconButton('a', 'card-btn', SVG_DOWNLOAD, 'Download');
    dl.href = RELEASES.replace(/\/latest$/, '/latest/download/') + dir + '.zip';
    dl.setAttribute('aria-label', 'Download ' + face.title + ' (' + dir + '.zip) from the latest release');
    foot.appendChild(dl);
  }
  card.appendChild(foot);
  const s = face.settings, words = [face.title];
  if (s) {
    for (const g of s.groups) { words.push(g.title); for (const it of g.items) { words.push(it.title); for (const o of it.options) words.push(o.label); } }
    if (s.native) words.push('on-watch editor customize', ...s.native.styles, ...s.native.dataColors);
    if (s.menu) words.push('on-watch menu');
  }
  card.dataset.search = words.join(' ').toLowerCase();
  redrawCard();
  grid.appendChild(card);
}
const empty = el('p', 'empty', 'No faces match.');
empty.hidden = true;
grid.appendChild(empty);
document.getElementById('search').addEventListener('input', ev => {
  const q = ev.target.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
  let shown = 0;
  for (const c of grid.querySelectorAll('.face')) {
    const hit = q.every(w => c.dataset.search.includes(w));
    c.hidden = !hit;
    if (hit) shown++;
  }
  empty.hidden = shown > 0;
  refit();
});
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
