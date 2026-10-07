import math, json, sys, os
OUT = sys.argv[1]
def P(r, deg, cx=195, cy=195):
    a = math.radians(deg); return cx + r*math.sin(a), cy - r*math.cos(a)
def arc(r, a0, a1):
    lo, hi = min(a0, a1), max(a0, a1)
    x0,y0 = P(r,lo); x1,y1 = P(r,hi); large = 1 if hi - lo > 180 else 0
    return f'M{x0:.1f} {y0:.1f} A{r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}'
FONTLINK = 'https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@800&amp;family=Roboto+Condensed:wght@500;600;700&amp;display=swap'
# ---- geometry measured from the reference photo (390 design units) ----
AR, ATRACK, AFILL = 175, 3.5, 8
CR = 51
CIRCLES = {'top': (195, 36), 'left': (36, 195), 'right': (354, 195), 'bottom': (195, 354)}
# arc: track [lo, hi]; fill grows from `start` toward the other end ("upward" along the rim); icon at the fill head
ARCS = {'tl': dict(lo=291, hi=339, start=291), 'tr': dict(lo=21, hi=69, start=69),
        'bl': dict(lo=201, hi=249, start=249), 'br': dict(lo=111, hi=159, start=111)}
CAP_DEG = math.degrees((AFILL / 2) / AR)  # fill inset so its round cap stays inside the track
TXT = {'tl': 315, 'tr': 45, 'bl': 225, 'br': 135}
TXT_R = {'tl': 141, 'tr': 141, 'bl': 141, 'br': 141}
_ICONS = {i['name']: i for i in json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'icons', 'meridian.json')))['icons']}
def ic(path, color, size, extra=''):
    # same artwork as the watch's icon font (tools/icons/meridian.json)
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{color}" stroke="{color}" stroke-width="0" {extra}>{path}</svg>'
STEPS, BOLT, CLOUDSUN, HEART = (_ICONS[n]['svg'] for n in ('FOOT', 'BOLT', 'PARTLY', 'HEART'))
CAL, SUNRISE, BELL = (_ICONS[n]['svg'] for n in ('CALENDAR', 'SUNRISE', 'BELL'))
def placed(svg, x, y, size):
    return f'<div style="position: absolute; left: {x-size/2:.1f}px; top: {y-size/2:.1f}px; width: {size}px; height: {size}px; display: flex">{svg}</div>'
def label(x, y, text, size, color, weight=700):
    return f'<div style="position: absolute; left: {x-60}px; top: {y-size*0.6:.1f}px; width: 120px; height: {size*1.2:.1f}px; display: flex; align-items: center; justify-content: center; font-family: \'Roboto Condensed\', sans-serif; font-weight: {weight}; font-size: {size}px; line-height: 1; color: {color}">{text}</div>'
def build(theme, aod=False):
    T = theme
    svg, html = [], []
    # rim marks at 12 and 6
    if False:
        for a in (0, 180):
            x0, y0 = P(184, a); x1, y1 = P(191, a)
            svg.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="{T["track"]}" stroke-width="3"></line>')
    fills = {'tl': .77, 'tr': .52, 'bl': .61, 'br': .32}
    cols = {'tl': T['steps'], 'tr': T['batt'], 'bl': T['weather'], 'br': T['heart']}
    icons = {'tl': (STEPS, 26), 'tr': (BOLT, 24), 'bl': (CLOUDSUN, 30), 'br': (HEART, 29)}  # 80% of the slot icons
    vals = {'tl': '12k', 'tr': '9d', 'bl': '27°', 'br': '61'}
    for k, a in ARCS.items():
        lo, hi, st = a['lo'], a['hi'], a['start']
        end = hi if st == lo else lo
        d0 = 1 if end > st else -1
        st, end = st + d0 * CAP_DEG, end - d0 * CAP_DEG
        head = st + (end - st) * fills[k]
        if not aod:
            svg.append(f'<path d="{arc(AR, lo, hi)}" stroke="{T["track"]}" stroke-width="{ATRACK}" stroke-linecap="round"></path>')
        if fills[k] > 0 and not aod:
            svg.append(f'<path d="{arc(AR, st, head)}" stroke="{"#4A4A4A" if aod else cols[k]}" stroke-width="{2 if aod else AFILL}" stroke-linecap="round"></path>')
        if not aod:
            d = 1 if end > st else -1
            ia = head + 3 * d
            if (ia - st) * d < 12: ia = st + 12 * d
            lim = (hi if d > 0 else lo) - 6 * d  # never closer than 6 deg to the arc end (clears the frame)
            if (ia - lim) * d > 0: ia = lim
            ix, iy = P(AR - 2, ia)
            path, size = icons[k]
            html.append(placed(ic(path, cols[k], size, 'style="filter: drop-shadow(2.5px 0 0 ' + T['bg'] + ') drop-shadow(-2.5px 0 0 ' + T['bg'] + ') drop-shadow(0 2.5px 0 ' + T['bg'] + ') drop-shadow(0 -2.5px 0 ' + T['bg'] + ')"'), ix, iy, size))
            ta = TXT[k]; tx, ty = P(TXT_R[k], ta)
            rot = ta if (ta > 270 or ta < 90) else ta - 180
            svg.append(f'<text x="{tx:.1f}" y="{ty:.1f}" transform="rotate({rot} {tx:.1f} {ty:.1f})" text-anchor="middle" dominant-baseline="central" font-family="Roboto Condensed" font-weight="500" font-size="33" fill="{T["text"]}">{vals[k]}</text>')
    if not aod:
        for k, (cx, cy) in CIRCLES.items():
            svg.append(f'<circle cx="{cx}" cy="{cy}" r="{CR}" stroke="{T["outline"]}" stroke-width="2.5"></circle>')
        html.append(placed(ic(CAL, T['cal'], 34), 195, 17, 34)); html.append(label(195, 60, '11:00', 33, T['text'], 500))
        html.append(placed(ic(SUNRISE, T['sun'], 36), 39, 177, 36)); html.append(label(39, 217, '7:24', 33, T['text'], 500))
        html.append(label(351, 178, 'SAT', 30, T['day'])); html.append(label(351, 217, '24', 33, T['text'], 500))
        html.append(placed(ic(BELL, T['bell'], 36), 195, 330, 36)); html.append(label(195, 373, '2', 33, T['text'], 500))
    # time: hour cap y 109..194 (center 152), minute cap 199..285 (center 242)
    stroke = '-webkit-text-stroke: 2px #8A8A8A; color: transparent;' if aod else ''
    for txt, cyc, col in (('12', 146, T['hour']), ('31', 244, T['min'])):
        color = '' if aod else (f'background: linear-gradient(180deg, {col} 55%, {T["hourEnd"]} 100%); -webkit-background-clip: text; background-clip: text; color: transparent;' if txt == '12' else f'color: {col};')
        html.append(f'<div style="position: absolute; left: 0; top: {cyc-60}px; width: 390px; height: 120px; display: flex; align-items: center; justify-content: center; '
                    f'font-family: \'M PLUS Rounded 1c\', sans-serif; font-weight: 800; font-size: 132px; line-height: 1; letter-spacing: -4px; {color}{stroke}">'
                    f'<span style="position: relative; top: 4px">{txt}</span></div>')
    if aod:
        html.append(label(195, 330, 'SAT 24 · ♥ 61', 18, '#6A6A6A', 600).replace('width: 120px', 'width: 200px').replace(f'left: {195-60}px', f'left: {195-100}px'))
    bg = '#000000' if aod else '{{accent}}'
    return (f'<div style="position: relative; width: 390px; height: 390px; border-radius: 50%; background: {bg}; overflow: hidden">\n'
            f'<svg width="390" height="390" viewBox="0 0 390 390" fill="none" style="position: absolute; left: 0; top: 0" aria-hidden="true">\n'
            + '\n'.join(svg) + '\n</svg>\n' + '\n'.join(html) + '\n</div>')
def page(title, body, props, script):
    return f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="{FONTLINK}">
<style>
body{{margin:0;background:#1a1a1a}}
</style>
</helmet>
{body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{json.dumps(props)}'>
{script}
</script>
</body>
</html>
'''
# theme values are filled by renderVals from the background choice
HOLES = {k: '{{' + k + '}}' for k in ['bg', 'hourEnd', 'track', 'outline', 'text', 'hour', 'min', 'day', 'steps', 'batt', 'weather', 'heart', 'cal', 'sun', 'bell']}
script = '''class Component extends DCLogic {
  renderVals() {
    const bg = (this.props.accent ?? '#0B0B0B').toUpperCase();
    const themes = {
      '#0B0B0B': { hourEnd: '#BDBDBD', track: '#4A4A4A', outline: '#3C3C3C', text: '#FFFFFF', hour: '#FFFFFF', min: '#FFFFFF', day: '#4A90E2',
                   steps: '#F0399F', batt: '#5BE15B', weather: '#F5A33A', heart: '#EF3348', cal: '#C8C8C8', sun: '#F7B52C', bell: '#F7E03A' },
      '#1B2A44': { hourEnd: '#9EE6C8', track: '#8E8E93', outline: '#8E8E93', text: '#E8E8EA', hour: '#C9E86B', min: '#A9D6FF', day: '#F2B9A6',
                   steps: '#7FB2E8', batt: '#D7DE8A', weather: '#E3A04E', heart: '#C8443A', cal: '#C8CCD6', sun: '#E8E070', bell: '#E3A04E' },
      '#F4EEE3': { hourEnd: '#1F4E5F', track: '#3E8EA3', outline: '#C9B79A', text: '#2B2B2B', hour: '#1F4E5F', min: '#B3412E', day: '#B3412E',
                   steps: '#3E8EA3', batt: '#3E8EA3', weather: '#3E8EA3', heart: '#3E8EA3', cal: '#B3412E', sun: '#B3412E', bell: '#B3412E' },
      '#20262E': { hourEnd: '#5FD3F3', track: '#55606C', outline: '#4A5562', text: '#FFFFFF', hour: '#9BF0B0', min: '#5FD3F3', day: '#5FD3F3',
                   steps: '#C6F432', batt: '#C6F432', weather: '#C6F432', heart: '#C6F432', cal: '#E6E6E6', sun: '#C6F432', bell: '#C6F432' }
    };
    return Object.assign({ accent: bg, bg: bg }, themes[bg] || themes['#0B0B0B']);
  }
}'''
props = {"accent": {"editor": "color", "default": "#0B0B0B", "options": ["#0B0B0B", "#1B2A44", "#F4EEE3", "#20262E"]},
         "$preview": {"width": 390, "height": 390}}
open(os.path.join(OUT, 'Meridian.dc.html'), 'w').write(page('Watch face AE: Meridian', build(HOLES), props, script))
open(os.path.join(OUT, 'MeridianAOD.dc.html'), 'w').write(page('Watch face AE: Always-on mode', build(HOLES, aod=True),
     {"$preview": {"width": 390, "height": 390}}, 'class Component extends DCLogic {\n  renderVals() {\n    return {};\n  }\n}'))
print('ok')
