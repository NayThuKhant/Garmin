import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Math;

// Face-local helpers (not part of the shared Data/Gfx copies).
module Ext {

    // Fraction a/b clamped to 0..1 (0 when unknown).
    function frac(a, b) as Float {
        if (a == null || b == null || b <= 0) { return 0.0; }
        var f = a.toFloat() / b.toFloat();
        return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
    }

    function dot(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var rr = r * Gfx.k;
        dc.fillCircle(Gfx.sx(x), Gfx.sy(y), rr < 1 ? 1 : rr);
    }

    // Line with round caps (design units).
    function roundLine(dc as Graphics.Dc, x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric,
                       color as Number, w as Numeric) as Void {
        Gfx.line(dc, x1, y1, x2, y2, color, w);
        if (w * Gfx.k >= 2.5) {
            dot(dc, x1, y1, w / 2.0, color);
            dot(dc, x2, y2, w / 2.0, color);
        }
    }

    // Arc in clock degrees with round caps.
    function roundArc(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric,
                      a0 as Numeric, a1 as Numeric, color as Number, w as Numeric) as Void {
        if (a1 - a0 < 0.5) { return; }
        Gfx.arc(dc, cx, cy, r, a0, a1, color, w);
        if (a1 - a0 < 359.5) {
            dot(dc, Gfx.px(cx, r, a0), Gfx.py(cy, r, a0), w / 2.0, color);
            dot(dc, Gfx.px(cx, r, a1), Gfx.py(cy, r, a1), w / 2.0, color);
        }
    }

    // ---- text rows with optional leading arrow (strings starting with "↑" / "↓") ----

    function _arrowW(size as Numeric) as Float { return size * 0.55; }

    function itemWidth(dc as Graphics.Dc, f as Graphics.FontType, size as Numeric, str as String) as Float {
        var first = str.length() > 0 ? str.substring(0, 1) : "";
        if (first.equals("↑") || first.equals("↓")) {
            return _arrowW(size) + size * 0.15 + Gfx.width(dc, str.substring(1, str.length()) as String, f);
        }
        return Gfx.width(dc, str, f);
    }

    // Draws one item left-aligned at x (cap center y), returns its width.
    function item(dc as Graphics.Dc, x as Numeric, y as Numeric, f as Graphics.FontType, size as Numeric,
                  str as String, color as Number) as Float {
        var first = str.length() > 0 ? str.substring(0, 1) : "";
        if (first.equals("↑") || first.equals("↓")) {
            var aw = _arrowW(size);
            arrow(dc, x + aw / 2, y, size, first.equals("↑"), color);
            var rest = str.substring(1, str.length()) as String;
            Gfx.text(dc, x + aw + size * 0.15, y, f, rest, color, Graphics.TEXT_JUSTIFY_LEFT);
            return aw + size * 0.15 + Gfx.width(dc, rest, f);
        }
        Gfx.text(dc, x, y, f, str, color, Graphics.TEXT_JUSTIFY_LEFT);
        return Gfx.width(dc, str, f);
    }

    // Arrow glyph sized like text of `size` px, centered at (cx, cy).
    function arrow(dc as Graphics.Dc, cx as Numeric, cy as Numeric, size as Numeric, up as Boolean, color as Number) as Void {
        var h = size * 0.38;
        var wing = size * 0.24;
        var tip = up ? cy - h : cy + h;
        var tail = up ? cy + h : cy - h;
        var wy = up ? tip + wing * 1.1 : tip - wing * 1.1;
        var pw = size / 9.0;
        Gfx.line(dc, cx, tail, cx, tip, color, pw);
        Gfx.line(dc, cx - wing, wy, cx, tip, color, pw);
        Gfx.line(dc, cx + wing, wy, cx, tip, color, pw);
    }

    // Row of items centered on cx; gaps[i] = gap after item i (design px).
    function row(dc as Graphics.Dc, cx as Numeric, cy as Numeric, f as Graphics.FontType, size as Numeric,
                 items as Array<String>, colors as Array<Number>, gaps as Array<Numeric>) as Void {
        var total = 0.0;
        for (var i = 0; i < items.size(); i++) {
            total += itemWidth(dc, f, size, items[i]);
            if (i < items.size() - 1) { total += gaps[i]; }
        }
        var x = cx - total / 2;
        for (var i = 0; i < items.size(); i++) {
            x += item(dc, x, cy, f, size, items[i], colors[i]);
            if (i < items.size() - 1) { x += gaps[i]; }
        }
    }

    // Header used by several faces: "MON 05 OCT", temperature, notifications.
    function tempStr() as String {
        var t = Data.temperature();
        return t != null ? t + "°" : "--°";
    }
}
