import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Math;

// Face-local drawing helpers on top of Gfx (design units, AOD shift aware).
module Extra {

    // Small vertical arrow (sunrise ^ / sunset v) of height h, centered at (cx,cy).
    function arrow(dc as Graphics.Dc, cx as Numeric, cy as Numeric, up as Boolean,
                   color as Number, h as Numeric) as Void {
        var half = h / 2.0;
        var tip = up ? cy - half : cy + half;
        var tail = up ? cy + half : cy - half;
        var wing = up ? tip + h * 0.35 : tip - h * 0.35;
        var w = h * 0.3;
        var pw = h * 0.13;
        Gfx.line(dc, cx, tail, cx, tip, color, pw);
        Gfx.line(dc, cx - w, wing, cx, tip, color, pw);
        Gfx.line(dc, cx + w, wing, cx, tip, color, pw);
    }

    function drawSeg(dc as Graphics.Dc, x as Numeric, cy as Numeric, f as Graphics.FontType,
                     seg as String, color as Number) as Float {
        Gfx.text(dc, x, cy, f, seg, color, Graphics.TEXT_JUSTIFY_LEFT);
        return Gfx.width(dc, seg, f);
    }

    // "Rich" text (letter-spacing is baked into bitmap fonts; `spacing` only pads the arrows): '^' draws a sunrise arrow, '~' a sunset arrow, everything else is text.
    // asz = arrow height in design px (0 -> 0.8 * font cap guess).
    function richWidth(dc as Graphics.Dc, f as Graphics.FontType, str as String,
                       spacing as Numeric, asz as Numeric) as Float {
        var w = 0.0;
        var seg = "";
        var chars = str.toCharArray();
        var n = 0;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c == '^' || c == '~') {
                if (seg.length() > 0) { w += Gfx.width(dc, seg, f); seg = ""; }
                w += asz * 0.7 + 2 + spacing;
                n++;
            } else {
                seg += c.toString();
            }
        }
        if (seg.length() > 0) { w += Gfx.width(dc, seg, f); } else if (n > 0) { w -= spacing; }
        return w.toFloat();
    }

    function rich(dc as Graphics.Dc, x as Numeric, cy as Numeric, f as Graphics.FontType, str as String,
                  color as Number, spacing as Numeric, asz as Numeric) as Float {
        var x0 = x;
        var seg = "";
        var chars = str.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c == '^' || c == '~') {
                if (seg.length() > 0) { x += drawSeg(dc, x, cy, f, seg, color); seg = ""; }
                arrow(dc, x + asz * 0.35, cy, c == '^', color, asz);
                x += asz * 0.7 + 2 + spacing;
            } else {
                seg += c.toString();
            }
        }
        if (seg.length() > 0) { x += drawSeg(dc, x, cy, f, seg, color); } else { x -= spacing; }
        return (x - x0).toFloat();
    }

    // Row of rich text items centered on cx with `gap` between them.
    function row(dc as Graphics.Dc, cx as Numeric, cy as Numeric, f as Graphics.FontType,
                 items as Array<String>, colors as Array<Number>, gap as Numeric,
                 spacing as Numeric, asz as Numeric) as Void {
        var total = gap * (items.size() - 1).toFloat();
        for (var i = 0; i < items.size(); i++) {
            total += richWidth(dc, f, items[i], spacing, asz);
        }
        var x = cx - total / 2;
        for (var i = 0; i < items.size(); i++) {
            x += rich(dc, x, cy, f, items[i], colors[i], spacing, asz) + gap;
        }
    }

    // "^5:58 ~17:52"
    function sunStr() as String {
        return "^" + Data.timeOf(Data.sunrise()) + " ~" + Data.timeOf(Data.sunset());
    }

    // Design-unit flat [x0,y0,x1,y1,...] -> device points.
    function pts(p as Array<Numeric>) as Array<[Numeric, Numeric]> {
        var out = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i + 1 < p.size(); i += 2) {
            out.add([Gfx.sx(p[i]), Gfx.sy(p[i + 1])]);
        }
        return out;
    }

    function fillPoly(dc as Graphics.Dc, p as Array<Numeric>, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts(p));
    }

    // Closed outline through the flat point list.
    function strokePoly(dc as Graphics.Dc, p as Array<Numeric>, color as Number, w as Numeric) as Void {
        var n = p.size();
        for (var i = 0; i + 1 < n; i += 2) {
            var j = (i + 2) % n;
            Gfx.line(dc, p[i], p[i + 1], p[j], p[j + 1], color, w);
        }
    }

    // Line with round caps.
    function capLine(dc as Graphics.Dc, x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric,
                     color as Number, w as Numeric) as Void {
        Gfx.line(dc, x1, y1, x2, y2, color, w);
        var r = w * Gfx.k / 2.0;
        if (r >= 1.0) {
            dc.fillCircle(Gfx.sx(x1), Gfx.sy(y1), r);
            dc.fillCircle(Gfx.sx(x2), Gfx.sy(y2), r);
        }
    }

    function dot(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var rr = r * Gfx.k;
        dc.fillCircle(Gfx.sx(x), Gfx.sy(y), rr < 1 ? 1 : rr);
    }

    // Filled pie wedge from clock angle a0 to a1 (degrees), including the center.
    function pie(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric,
                 a0 as Numeric, a1 as Numeric, color as Number) as Void {
        if (a1 - a0 < 0.5) { return; }
        var p = [cx, cy] as Array<Numeric>;
        var n = Math.ceil((a1 - a0) / 12.0).toNumber();
        if (n < 1) { n = 1; }
        for (var i = 0; i <= n; i++) {
            var a = a0 + (a1 - a0) * i / n.toFloat();
            p.add(Gfx.px(cx, r, a));
            p.add(Gfx.py(cy, r, a));
        }
        fillPoly(dc, p, color);
    }

    // Arc with round end caps.
    function capArc(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric,
                    a0 as Numeric, a1 as Numeric, color as Number, w as Numeric) as Void {
        if (a1 - a0 < 0.5) { return; }
        Gfx.arc(dc, cx, cy, r, a0, a1, color, w);
        if (a1 - a0 < 359.5) {
            dot(dc, Gfx.px(cx, r, a0), Gfx.py(cy, r, a0), w / 2.0, color);
            dot(dc, Gfx.px(cx, r, a1), Gfx.py(cy, r, a1), w / 2.0, color);
        }
    }

    function clamp01(v as Float) as Float {
        return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    }

    // value/goal clamped to 0..1, 0 when either is missing.
    function frac(v as Numeric or Null, goal as Numeric or Null) as Float {
        if (v == null || goal == null || goal <= 0) { return 0.0; }
        return clamp01(v.toFloat() / goal);
    }
}
