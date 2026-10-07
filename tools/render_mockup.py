#!/usr/bin/env python3
"""Render one mockup to a PNG with headless Chrome (to compare against references or the simulator).

Usage: python3 tools/render_mockup.py mockups/Meridian.dc.html out.png [scale] [props-json]
  scale: device pixel ratio (default 2 -> 780x780)
  props-json: overrides for the mockup's props, e.g. '{"accent": "#1B2A44"}'
"""
import json, os, re, subprocess, sys, tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def main(src, out, scale="2", overrides="{}"):
    html = open(src).read()
    body = html.split("</helmet>", 1)[1].split("</x-dc>", 1)[0]
    helmet = html.split("<helmet>", 1)[1].split("</helmet>", 1)[0]
    m = re.search(r"data-props='(.*?)'>(.*?)</script>", html, re.S)
    props = {k: (v.get("default") if isinstance(v, dict) else v)
             for k, v in json.loads(m.group(1)).items() if not k.startswith("$")}
    props.update(json.loads(overrides))
    page = f"""<!doctype html><html><head><meta charset="utf-8">{helmet}
<style>html,body{{margin:0;background:#000}}</style></head><body>
<div id="root"></div>
<script>
class DCLogic {{ constructor(p) {{ this.props = p; }} }}
{m.group(2)}
const vals = new Component({json.dumps(props)}).renderVals() || {{}};
const tpl = {json.dumps(body)};
document.getElementById('root').innerHTML = tpl.replace(/{{{{\\s*([\\w.]+)\\s*}}}}/g,
  (m, p) => {{ const v = p.split('.').reduce((o, k) => o == null ? o : o[k], vals); return v == null ? '' : v; }});
</script></body></html>"""
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(page)
        tmp = f.name
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    f"--force-device-scale-factor={scale}", "--window-size=390,390",
                    "--virtual-time-budget=4000", f"--screenshot={os.path.abspath(out)}",
                    "file://" + tmp], check=True, capture_output=True)
    os.unlink(tmp)
    print(out)


if __name__ == "__main__":
    main(*sys.argv[1:])
