#!/usr/bin/env python3
"""Bundle every mockup in mockups/ into one self-contained faces.html (open it in a browser).

Usage: python3 tools/build_gallery.py   -> writes faces.html at the repo root

Faces are listed in mockups/canvas.json order, active + always-on side by side. Each mockup's
markup ({{holes}}) and its renderVals() script are embedded and evaluated in the page, with the
props' defaults; accent swatches re-render a face with another option.
"""
import json, os, re

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
            entry = {"title": base, "boards": []}
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
.swatches { display: flex; gap: 6px; margin-top: 10px; }
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
  if (accent && accent.props.accent.options) {
    const sw = document.createElement('div');
    sw.className = 'swatches';
    sw.setAttribute('role', 'group');
    sw.setAttribute('aria-label', face.title + ' accent');
    for (const c of accent.props.accent.options) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.style.background = c;
      btn.setAttribute('aria-label', 'Accent ' + c);
      btn.setAttribute('aria-pressed', c === accent.props.accent.default ? 'true' : 'false');
      btn.addEventListener('click', () => {
        state.accent = c;
        sw.querySelectorAll('button').forEach(x => x.setAttribute('aria-pressed', x === btn ? 'true' : 'false'));
        draw.forEach(f => f());
      });
      sw.appendChild(btn);
    }
    card.appendChild(sw);
  }
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
