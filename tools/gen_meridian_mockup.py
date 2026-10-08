#!/usr/bin/env python3
"""Generate the AE · Meridian mockups (mockups/Meridian.dc.html + MeridianAOD.dc.html).

Usage: python3 tools/gen_meridian_mockup.py mockups

The mockup draws itself in JavaScript from the SAME settings as the watch code (props named after the
properties in faces/MeridianFace/resources/properties/properties.xml: Theme, FontStyle, Frame, SlotTop,
ArcTL, HourColor, ...), so faces.html can let you click any setting and see the real result. Geometry,
theme tables, option icons/colors and color rules mirror faces/MeridianFace/source/*.mc — keep in sync
(geometry is checked by tools/check_meridian.py against the code).
"""
import json, math, os, sys

OUT = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = {i['name']: i for i in json.load(open(os.path.join(HERE, 'icons', 'meridian.json')))['icons']}

FONTLINK = ('https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@800&amp;family=Chakra+Petch:wght@700'
            '&amp;family=DM+Serif+Display&amp;family=Barlow+Condensed:wght@600'
            '&amp;family=Roboto+Condensed:wght@500;600;700&amp;display=swap')

# ---- geometry (390 design units) = faces/MeridianFace/source/MeridianView.mc ----
G = {
    'AR': 175, 'TRACK': 3.5, 'FILL': 8, 'CR': 51,
    'SLOT': [[195, 36], [36, 195], [354, 195], [195, 354]],          # top, left, right, bottom
    'ICON': [[195, 17], [39, 177], [351, 177], [195, 330]], 'ICON_SZ': [34, 36, 36, 36],
    'VALUE': [[195, 60], [39, 217], [351, 217], [195, 373]],
    'ARC_A': [291, 21, 201, 111], 'ARC_B': [339, 69, 249, 159],
    'ARC_BASE': [291, 69, 249, 111], 'ARC_END': [339, 21, 201, 159],
    'ARC_TEXT': [315, 45, 225, 135], 'ARC_TEXT_R': 141,
    'HOUR_Y': 146, 'MIN_Y': 244,
}
# ---- themes: Black, Navy, Charcoal, Cream, White = MeridianView.mc ----
T = {
    'BG': ['#0B0B0B', '#1B2A44', '#20262E', '#F4EEE3', '#FFFFFF'],
    'TEXT': ['#FFFFFF', '#E8E8EA', '#FFFFFF', '#2B2B2B', '#1B1B1B'],
    'OUTLINE': ['#3C3C3C', '#8E8E93', '#4A5562', '#C9B79A', '#BDBDBD'],
    'TRACK': ['#4A4A4A', '#8E8E93', '#55606C', '#3E8EA3', '#D6D6D6'],
    'WEEKDAY': ['#4A90E2', '#F2B9A6', '#5FD3F3', '#B3412E', '#4A90E2'],
    'HOUR': ['#FFFFFF', '#C9E86B', '#9BF0B0', '#1F4E5F', '#1F4E5F'],
    'HOUR_END': ['#BDBDBD', '#9EE6C8', '#5FD3F3', '#1F4E5F', '#1F4E5F'],
    'MINUTE': ['#FFFFFF', '#A9D6FF', '#5FD3F3', '#B3412E', '#B3412E'],
    'NAVY_ARCS': ['#7FB2E8', '#D7DE8A', '#E3A04E', '#C8443A'],
    'CREAM_ACCENT': '#3E8EA3', 'CREAM_ICON': '#B3412E', 'CHARCOAL_ACCENT': '#C6F432',
    'GRAD': ['#FFFFFF', '#B4B4B4', '#C6F432', '#2DD4BF', '#C6F432', '#CFE8C8', '#C6F432', '#A9D3FF',
             '#FF3DA5', '#FFA62B', '#A9D3FF', '#B9B4F5', '#FFC21A', '#FF3B4E', '#2DD4BF', '#4DA3FF'],
}
# ---- data options = MeridianData.mc enum order: [icon, label, sample value, arc progress, color] ----
OPTS = [
    [None, None, '', None, '#8A8A8A'],                       # NONE
    ['FOOT', None, '12k', .72, '#F0399F'],                   # STEPS
    ['TARGET', None, '72%', .72, '#F0399F'],                 # STEPS_PCT
    ['PIN', None, '5.6km', None, '#4DA3FF'],                 # DISTANCE
    ['FLAME', None, '1.8k', None, '#FF7A3D'],                # CALORIES
    ['STOPWATCH', None, '95', .63, '#F5A33A'],               # INTENSITY
    ['HEART', None, '61', .32, '#EF3348'],                   # HR
    ['HEART', None, '52', .52, '#FF6B7A'],                   # RHR
    ['BODY', None, '68', .68, '#4DC3FF'],                    # BODY_BATT
    ['STRESS', None, '24', .24, '#F5A33A'],                  # STRESS
    ['O2', None, '97%', .97, '#4DA3FF'],                     # SPO2
    ['LUNGS', None, '14', None, '#7DD3FC'],                  # RESP
    ['BATT4', None, '82%', .82, '#5BE15B'],                  # BATT
    ['BOLT', None, '9d', .6, '#5BE15B'],                     # BATT_DAYS
    ['THERMO', None, '27°', None, '#F5A33A'],                # TEMP
    ['PARTLY', None, '27°', None, '#F5A33A'],                # WEATHER
    ['THERMO', None, '31/24', None, '#F5A33A'],              # HILO
    ['UMBRELLA', None, '20%', .2, '#4DA3FF'],                # PRECIP
    ['DROP', None, '64%', .64, '#4DA3FF'],                   # HUMIDITY
    ['WIND', None, '12kmh', None, '#7DD3FC'],                # WIND
    [None, 'UV', '7', .64, '#FFC21A'],                       # UV
    ['SUNRISE', None, '7:24', None, '#F7B52C'],              # SUNRISE
    ['SUNSET', None, '17:52', None, '#FF7A3D'],              # SUNSET
    ['SUNSET', None, '17:52', None, '#F7B52C'],              # NEXT_SUN
    ['BELL', None, '2', None, '#F7E03A'],                    # NOTIF
    ['ALARM', None, '1', None, '#FFC21A'],                   # ALARMS
    ['PHONE', None, 'ON', None, '#4DA3FF'],                  # PHONE
    [None, 'SAT', '24', None, '#4A90E2'],                    # DATE
    [None, 'WK', '40', None, '#C8C8C8'],                     # WEEK
    ['MOUNTAIN', None, '42', None, '#B9A6FF'],               # ALTITUDE
    ['RECOVERY', None, '26h', .3, '#FFE11A'],                # RECOVERY
    ['TREND', None, 'PRODUCTI', None, '#5BE15B'],            # TRAINING
    ['GAUGE', None, '48', None, '#FF7A3D'],                  # VO2
    ['MOON', None, '81', .81, '#B9A6FF'],                    # SLEEP
    ['CALENDAR', None, '11:00', None, '#C8C8C8'],            # CALENDAR
    ['STAIRS', None, '12', None, '#6EE7B7'],                 # FLOORS
    ['BARO', None, '1013', None, '#B9A6FF'],                 # PRESSURE
]
NOTE_IDX = {'CALENDAR': 34, 'SUNRISE': 21, 'SUNSET': 22, 'NEXT_SUN': 23, 'NOTIF': 24}
# font styles = fonts.json TimeRound / TimeSquare / TimeSerif / TimeClassic
FONTS = [["'M PLUS Rounded 1c'", 800, -4], ["'Chakra Petch'", 700, -4], ["'DM Serif Display'", 400, -3], ["'Barlow Condensed'", 600, -2]]
ICON_SVG = {k: [v['svg'], v['size']] for k, v in ICONS.items()}
DEFAULTS = {'Theme': 0, 'FontStyle': 0, 'Frame': 0, 'TimeFormat': 0, 'LeadingZero': True,
            'SlotTop': 34, 'SlotLeft': 21, 'SlotRight': 27, 'SlotBottom': 24,
            'ArcTL': 1, 'ArcTR': 13, 'ArcBL': 15, 'ArcBR': 6,
            'HourColor': -1, 'MinuteColor': -1, 'WeekdayColor': -1, 'TextColor': -1, 'IconColor': -1,
            'OutlineColor': -1, 'TrackColor': -1, 'ArcColorTL': -1, 'ArcColorTR': -1, 'ArcColorBL': -1, 'ArcColorBR': -1}

JS = r'''
const G = __G__, T = __T__, OPTS = __OPTS__, ICONS = __ICONS__, FONTS = __FONTS__, NOTE = __NOTE__;
const AUTO = -1, DYN = -10;
const hex = v => typeof v === 'string' ? v : '#' + (v & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase();
const num = (p, k, d) => { const v = p[k]; if (v === undefined || v === null || v === '') return d; return typeof v === 'boolean' ? v : Number(v); };
function P(r, deg) { const a = deg * Math.PI / 180; return [195 + r * Math.sin(a), 195 - r * Math.cos(a)]; }
function arcPath(r, a0, a1) {
  const lo = Math.min(a0, a1), hi = Math.max(a0, a1), [x0, y0] = P(r, lo), [x1, y1] = P(r, hi);
  return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${r} ${r} 0 ${hi - lo > 180 ? 1 : 0} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
}
function iconHtml(name, x, y, size, color, bg) {
  const ic = ICONS[name]; if (!ic) return '';
  const halo = bg ? `filter: drop-shadow(2.5px 0 0 ${bg}) drop-shadow(-2.5px 0 0 ${bg}) drop-shadow(0 2.5px 0 ${bg}) drop-shadow(0 -2.5px 0 ${bg});` : '';
  return `<div style="position:absolute;left:${(x - size / 2).toFixed(1)}px;top:${(y - size / 2).toFixed(1)}px;width:${size}px;height:${size}px;display:flex;${halo}">` +
         `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="${color}" stroke="${color}" stroke-width="0">${ic[0]}</svg></div>`;
}
function textHtml(x, y, s, size, color, weight) {
  return `<div style="position:absolute;left:${x - 70}px;top:${(y - size * 0.6).toFixed(1)}px;width:140px;height:${(size * 1.2).toFixed(1)}px;display:flex;align-items:center;justify-content:center;font-family:'Roboto Condensed',sans-serif;font-weight:${weight};font-size:${size}px;line-height:1;color:${color};white-space:nowrap">${s}</div>`;
}
function settings(p) {
  const s = {};
  for (const k of Object.keys(__DEFAULTS__)) s[k] = num(p, k, __DEFAULTS__[k]);
  s.Theme = Math.min(4, Math.max(0, s.Theme | 0));
  return s;
}
function arcColor(s, i, opt) {
  let c = s['ArcColor' + ['TL', 'TR', 'BL', 'BR'][i]];
  if (c === AUTO) {
    if (s.Theme === 1) return T.NAVY_ARCS[i];
    if (s.Theme === 2) return T.CHARCOAL_ACCENT;
    if (s.Theme === 3) return T.CREAM_ACCENT;
    c = DYN;
  }
  return c === DYN ? OPTS[opt][4] : hex(c);
}
function iconColor(s, opt) {
  let c = s.IconColor;
  if (c === AUTO) {
    if (s.Theme === 1) {
      if (opt === NOTE.CALENDAR) return '#C8CCD6';
      if (opt === NOTE.SUNRISE || opt === NOTE.SUNSET || opt === NOTE.NEXT_SUN) return '#E8E070';
      if (opt === NOTE.NOTIF) return '#E3A04E';
    } else if (s.Theme === 2) return opt === NOTE.CALENDAR ? '#E6E6E6' : T.CHARCOAL_ACCENT;
    else if (s.Theme === 3) return T.CREAM_ICON;
    c = DYN;
  }
  return c === DYN ? OPTS[opt][4] : hex(c);
}
const pick = (v, auto) => v === AUTO ? auto : hex(v);
function digitStyle(c, autoTop, autoEnd) {
  // solid color, theme auto (solid to 55%, then fading), or a gradient setting (negative value)
  if (c === AUTO) return autoTop === autoEnd ? `color:${autoTop};` :
    `background:linear-gradient(180deg, ${autoTop} 55%, ${autoEnd} 100%);-webkit-background-clip:text;background-clip:text;color:transparent;`;
  if (c >= 0) return `color:${hex(c)};`;
  let g = (-c - 2) * 2; if (g < 0 || g + 1 >= T.GRAD.length) g = 0;
  return `background:linear-gradient(180deg, ${T.GRAD[g]}, ${T.GRAD[g + 1]});-webkit-background-clip:text;background-clip:text;color:transparent;`;
}
function timeHtml(s, aod) {
  const f = FONTS[Math.min(3, Math.max(0, s.FontStyle | 0))];
  const is24 = s.TimeFormat === 2 || s.TimeFormat === 0;   // sample time 12:31; "Follow watch" shown as 24 h
  let h = 12; if (!is24) { h = h % 12 || 12; }
  const hs = s.LeadingZero ? String(h).padStart(2, '0') : String(h);
  const line = (txt, y, style) => `<div style="position:absolute;left:0;top:${y - 60}px;width:390px;height:120px;display:flex;align-items:center;justify-content:center;font-family:${f[0]},sans-serif;font-weight:${f[1]};font-size:132px;line-height:1;letter-spacing:${f[2]}px;${style}"><span style="position:relative;top:4px">${txt}</span></div>`;
  if (aod) {
    const st = 'color:transparent;-webkit-text-stroke:2px #8A8A8A;';
    return line(hs, G.HOUR_Y, st) + line('31', G.MIN_Y, st);
  }
  const th = s.Theme;
  return line(hs, G.HOUR_Y, digitStyle(s.HourColor, T.HOUR[th], T.HOUR_END[th])) +
         line('31', G.MIN_Y, digitStyle(s.MinuteColor, T.MINUTE[th], T.MINUTE[th]));
}
function frameSvg(s, k, color) {
  const [cx, cy] = G.SLOT[k];
  if (s.Frame === 2) return '';
  if (s.Frame === 0) return `<circle cx="${cx}" cy="${cy}" r="${G.CR}" stroke="${color}" stroke-width="2.5"></circle>`;
  const r = G.CR + 3, rot = (k === 0 || k === 3) ? Math.PI / 6 : 0, pts = [];
  for (let i = 0; i < 6; i++) pts.push((cx + r * Math.cos(rot + Math.PI * i / 3)).toFixed(1) + ',' + (cy + r * Math.sin(rot + Math.PI * i / 3)).toFixed(1));
  return `<polygon points="${pts.join(' ')}" stroke="${color}" stroke-width="2.5" stroke-linejoin="round"></polygon>`;
}
function render(p, aod) {
  const s = settings(p), th = s.Theme, bg = T.BG[th];
  const text = pick(s.TextColor, T.TEXT[th]), outline = pick(s.OutlineColor, T.OUTLINE[th]), track = pick(s.TrackColor, T.TRACK[th]);
  let svg = '', html = '';
  if (aod) {
    html = timeHtml(s, true) + textHtml(195, 330, 'SAT 24 · ♥ 61', 18, '#6A6A6A', 600);
    return { bg: '#000000', content: html };
  }
  // circles (top, left, right, bottom)
  ['SlotTop', 'SlotLeft', 'SlotRight', 'SlotBottom'].forEach((key, k) => {
    svg += frameSvg(s, k, outline);
    const opt = s[key] | 0, o = OPTS[opt] || OPTS[0];
    if (!opt) return;
    if (o[1]) html += textHtml(G.ICON[k][0], G.SLOT[k][1] - 17, o[1], 30, pick(s.WeekdayColor, T.WEEKDAY[th]), 700);
    else html += iconHtml(o[0], G.ICON[k][0], G.ICON[k][1], G.ICON_SZ[k], iconColor(s, opt), null);
    html += textHtml(G.VALUE[k][0], G.VALUE[k][1], o[2], o[2].length > 5 ? 24 : 33, text, 500);
  });
  // arcs (TL, TR, BL, BR): identical mirrored shape, fill grows from the side circle
  const cap = (G.FILL / 2) / G.AR * 180 / Math.PI;
  ['ArcTL', 'ArcTR', 'ArcBL', 'ArcBR'].forEach((key, i) => {
    const opt = s[key] | 0, o = OPTS[opt] || OPTS[0];
    if (!opt) return;
    svg += `<path d="${arcPath(G.AR, G.ARC_A[i], G.ARC_B[i])}" stroke="${track}" stroke-width="${G.TRACK}" stroke-linecap="round"></path>`;
    const d = G.ARC_END[i] > G.ARC_BASE[i] ? 1 : -1, base = G.ARC_BASE[i] + d * cap, end = G.ARC_END[i] - d * cap;
    const color = arcColor(s, i, opt), prog = o[3] == null ? 0 : o[3];
    let head = base + (end - base) * prog;
    if ((head - base) * d < 2) {
      const [x, y] = P(G.AR, base); head = base;
      svg += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${G.FILL / 2}" fill="${color}"></circle>`;
    } else svg += `<path d="${arcPath(G.AR, base, head)}" stroke="${color}" stroke-width="${G.FILL}" stroke-linecap="round"></path>`;
    let ia = head + 3 * d;
    if ((ia - base) * d < 12) ia = base + 12 * d;
    const lim = G.ARC_END[i] - 6 * d; if ((ia - lim) * d > 0) ia = lim;
    const [ix, iy] = P(G.AR - 2, ia);
    if (o[0]) html += iconHtml(o[0], ix, iy, Math.round((ICONS[o[0]] || [0, 32])[1] * 0.8), color, bg);
    const ta = G.ARC_TEXT[i], [tx, ty] = P(G.ARC_TEXT_R, ta), rot = (ta > 270 || ta < 90) ? ta : ta - 180;
    const val = (o[1] ? o[1] + ' ' : '') + o[2];
    svg += `<text x="${tx.toFixed(1)}" y="${ty.toFixed(1)}" transform="rotate(${rot} ${tx.toFixed(1)} ${ty.toFixed(1)})" text-anchor="middle" dominant-baseline="central" font-family="Roboto Condensed" font-weight="500" font-size="33" fill="${text}">${val}</text>`;
  });
  html = `<svg width="390" height="390" viewBox="0 0 390 390" fill="none" style="position:absolute;left:0;top:0" aria-hidden="true">${svg}</svg>` + html + timeHtml(s, false);
  return { bg, content: html };
}
'''


def script(aod):
    js = (JS.replace('__G__', json.dumps(G)).replace('__T__', json.dumps(T)).replace('__OPTS__', json.dumps(OPTS, ensure_ascii=False))
          .replace('__ICONS__', json.dumps(ICON_SVG))
          .replace('__FONTS__', json.dumps(FONTS)).replace('__NOTE__', json.dumps(NOTE_IDX))
          .replace('__DEFAULTS__', json.dumps(DEFAULTS)))
    return js + ('class Component extends DCLogic {\n  renderVals() {\n    return render(this.props, %s);\n  }\n}' % ('true' if aod else 'false'))


def page(title, props, aod):
    body = ('<div style="position: relative; width: 390px; height: 390px; border-radius: 50%; background: {{bg}}; '
            'overflow: hidden; color: #FFFFFF">{{content}}</div>')
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
<script type="text/x-dc" data-dc-script data-props='{json.dumps(props, ensure_ascii=False)}'>
{script(aod)}
</script>
</body>
</html>
'''


# Props named after the watch's settings, so faces.html can drive them (values = the code's values).
props = {k: {'default': v} for k, v in DEFAULTS.items()}
props['Theme']['swatches'] = T['BG']
props['$preview'] = {'width': 390, 'height': 390}
open(os.path.join(OUT, 'Meridian.dc.html'), 'w').write(page('Watch face AE: Meridian', props, False))
aod_props = {k: {'default': DEFAULTS[k]} for k in ('FontStyle', 'TimeFormat', 'LeadingZero')}
aod_props['$preview'] = {'width': 390, 'height': 390}
open(os.path.join(OUT, 'MeridianAOD.dc.html'), 'w').write(page('Watch face AE: Always-on mode', aod_props, True))
print('ok')
