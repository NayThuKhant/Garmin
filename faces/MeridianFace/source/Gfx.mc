import Toybox.Lang;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;

// Shared drawing helpers. All coordinates and sizes are in 390-px design units;
// call Gfx.setup(dc) at the top of onUpdate, then use Gfx.x()/Gfx.font() etc.
// Copy this file unchanged into new faces.
module Gfx {

    var k as Float = 1.0;           // device px per design unit
    var dx as Numeric = 0;          // global offset in design units (AOD burn-in shift)
    var dy as Numeric = 0;
    var _fonts as Dictionary = {};  // cache key -> FontType

    const COND = "RobotoCondensedBold";
    const COND_REG = "RobotoCondensedRegular";
    const SANS = "RobotoRegular";

    function setup(dc as Graphics.Dc) as Void {
        k = dc.getWidth() / 390.0;
        dx = 0;
        dy = 0;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    // Design units -> device px, for sizes/lengths.
    function s(v as Numeric) as Number {
        return Math.round(v * k).toNumber();
    }

    // Design position -> device px, including the AOD offset.
    function sx(v as Numeric) as Number {
        return Math.round((v + dx) * k).toNumber();
    }
    function sy(v as Numeric) as Number {
        return Math.round((v + dy) * k).toNumber();
    }

    // Accent color from settings, falling back to `def`.
    function accent(def as Number) as Number {
        var v = Application.Properties.getValue("AccentColor");
        return v instanceof Number ? v : def;
    }

    // Vector font of `size` design px (CSS font-size). `face` is one of COND,
    // COND_REG, SANS. Falls back to the nearest system font on older devices.
    function font(face as String, size as Numeric) as Graphics.FontType {
        var px = s(size);
        var key = face + px;
        var f = _fonts[key];
        if (f != null) { return f as Graphics.FontType; }
        if (Graphics has :getVectorFont) {
            f = Graphics.getVectorFont({:face => [face, SANS], :size => px});
        }
        if (f == null) {
            f = _systemFont(px);
        }
        _fonts[key] = f;
        return f as Graphics.FontType;
    }

    function _systemFont(px as Number) as Graphics.FontType {
        if (px >= 110) { return Graphics.FONT_NUMBER_THAI_HOT; }
        if (px >= 80) { return Graphics.FONT_NUMBER_HOT; }
        if (px >= 55) { return Graphics.FONT_NUMBER_MEDIUM; }
        if (px >= 30) { return Graphics.FONT_NUMBER_MILD; }
        if (px >= 20) { return Graphics.FONT_MEDIUM; }
        if (px >= 15) { return Graphics.FONT_SMALL; }
        if (px >= 11) { return Graphics.FONT_TINY; }
        return Graphics.FONT_XTINY;
    }

    // Device y of the text top so that capitals/digits are vertically centered at design y.
    // For a CSS box (top T, line-height L) the cap center is about T + L/2.
    function capTop(f as Graphics.FontType, y as Numeric) as Number {
        return sy(y) - Math.round(Graphics.getFontAscent(f) * 0.617).toNumber();
    }

    // Draw text with capitals/digits centered at design y (justify: Graphics.TEXT_JUSTIFY_LEFT/CENTER/RIGHT).
    function text(dc as Graphics.Dc, x as Numeric, y as Numeric, f as Graphics.FontType,
                  str as String, color as Number, justify as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx(x), capTop(f, y), f, str, justify);
    }

    // Spread letters by `spacing` design px (CSS letter-spacing), left-aligned at x,
    // centered vertically at y. Returns the drawn width in design px.
    function spaced(dc as Graphics.Dc, x as Numeric, y as Numeric, f as Graphics.FontType,
                    str as String, color as Number, spacing as Numeric) as Float {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var cx = (x + dx) * k;
        var top = capTop(f, y);
        var chars = str.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toString();
            dc.drawText(cx.toNumber(), top, f, c, Graphics.TEXT_JUSTIFY_LEFT);
            cx += dc.getTextWidthInPixels(c, f) + spacing * k;
        }
        return (cx / k - dx - x - spacing).toFloat();
    }

    // Width (design px) of letter-spaced text.
    function spacedWidth(dc as Graphics.Dc, f as Graphics.FontType, str as String, spacing as Numeric) as Float {
        return dc.getTextWidthInPixels(str, f) / k + spacing * (str.length() - 1);
    }

    // Letter-spaced text centered on x.
    function spacedCenter(dc as Graphics.Dc, x as Numeric, y as Numeric, f as Graphics.FontType,
                          str as String, color as Number, spacing as Numeric) as Void {
        spaced(dc, x - spacedWidth(dc, f, str, spacing) / 2, y, f, str, color, spacing);
    }

    function width(dc as Graphics.Dc, str as String, f as Graphics.FontType) as Float {
        return dc.getTextWidthInPixels(str, f) / k;
    }

    function line(dc as Graphics.Dc, x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric,
                  color as Number, w as Numeric) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w * k < 1 ? 1 : Math.round(w * k).toNumber());
        dc.drawLine(sx(x1), sy(y1), sx(x2), sy(y2));
    }

    function rect(dc as Graphics.Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx(x), sy(y), s(w) < 1 ? 1 : s(w), s(h) < 1 ? 1 : s(h));
    }

    // Arc on circle (cx,cy,r), from angle a0 to a1 in CLOCK degrees
    // (0 = 12 o'clock, increasing clockwise), stroke width w.
    function arc(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric,
                 a0 as Numeric, a1 as Numeric, color as Number, w as Numeric) as Void {
        if (a1 - a0 < 0.5) { return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(w) < 1 ? 1 : s(w));
        if (a1 - a0 >= 359.5) {
            dc.drawCircle(sx(cx), sy(cy), s(r));
            return;
        }
        dc.drawArc(sx(cx), sy(cy), s(r), Graphics.ARC_CLOCKWISE, 90 - a0, 90 - a1);
    }

    // Point on circle at clock angle (degrees), in design units.
    function px(cx as Numeric, r as Numeric, deg as Numeric) as Float {
        return (cx + r * Math.sin(Math.toRadians(deg))).toFloat();
    }
    function py(cy as Numeric, r as Numeric, deg as Numeric) as Float {
        return (cy - r * Math.cos(Math.toRadians(deg))).toFloat();
    }

    // Burn-in shift for always-on: moves everything drawn through Gfx by up to 4 design px.
    // Consecutive minutes always differ in both x and y (diagonal steps), so no edge stays put.
    function aodShift() as Void {
        var m = System.getClockTime().min % 4;
        var xs = [-4, 0, 4, 0];
        var ys = [0, 4, 0, -4];
        dx = xs[m];
        dy = ys[m];
    }

    // AMOLED always-on rule: no pixel may stay lit more than ~3 minutes and <10% may be lit, or
    // the watch replaces the face with its own always-on screen. Blacking out every other pixel row,
    // alternating each minute, guarantees every pixel is off at least every other minute (and
    // halves the lit area). Call LAST in onUpdate while sleeping.
    function aodMask(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (dc has :setAntiAlias) { dc.setAntiAlias(false); }
        for (var y = System.getClockTime().min % 2; y < h; y += 2) {
            dc.drawLine(0, y, w, y);
        }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
    }

    // Scale an RGB color's brightness (0..1).
    function dim(color as Number, f as Float) as Number {
        var r = ((color >> 16) & 0xFF) * f;
        var g = ((color >> 8) & 0xFF) * f;
        var b = (color & 0xFF) * f;
        return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
    }

    // ---- icons (Lucide-style strokes on a 24-unit grid) ----

    // Polyline through flat [x0,y0,x1,y1,...] in 24-grid units, icon top-left at (ox,oy), size sz.
    function _poly(dc as Graphics.Dc, pts as Array<Numeric>, ox as Numeric, oy as Numeric, sz as Numeric) as Void {
        var f = sz / 24.0;
        for (var i = 2; i < pts.size(); i += 2) {
            dc.drawLine(sx(ox + pts[i - 2] * f), sy(oy + pts[i - 1] * f), sx(ox + pts[i] * f), sy(oy + pts[i + 1] * f));
        }
    }

    // Draw icon `name` centered at (cx,cy), size sz design px.
    // Names: :heart :steps :flame :bolt :pulse :drop :battery :sunrise :sunset :bell :moon :sun :cloud :pin
    function icon(dc as Graphics.Dc, name as Symbol, cx as Numeric, cy as Numeric, sz as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pw = Math.round(sz * 2.2 / 24.0 * k).toNumber();
        dc.setPenWidth(pw < 1 ? 1 : pw);
        var ox = cx - sz / 2.0;
        var oy = cy - sz / 2.0;
        var f = sz / 24.0;
        if (name == :heart) {
            var pts = [] as Array<Numeric>;
            for (var t = 0; t <= 32; t++) {
                var a = Math.PI * 2 * t / 32;
                var sn = Math.sin(a);
                pts.add(12 + 10.5 * sn * sn * sn);
                pts.add(11 - (8 * Math.cos(a) - 3 * Math.cos(2 * a) - 1.2 * Math.cos(3 * a) - 0.6 * Math.cos(4 * a)));
            }
            _poly(dc, pts, ox, oy, sz);
        } else if (name == :steps) {
            dc.drawEllipse(sx(ox + 7 * f), sy(oy + 8.5 * f), s(3.2 * f), s(5.5 * f));
            dc.drawEllipse(sx(ox + 17 * f), sy(oy + 12.5 * f), s(3.2 * f), s(5.5 * f));
            dc.drawLine(sx(ox + 4.5 * f), sy(oy + 17 * f), sx(ox + 9.5 * f), sy(oy + 17 * f));
            dc.drawLine(sx(ox + 14.5 * f), sy(oy + 21 * f), sx(ox + 19.5 * f), sy(oy + 21 * f));
        } else if (name == :flame) {
            _poly(dc, [12, 2, 15, 7, 18.5, 11, 19, 15, 17, 19.5, 12, 22, 7, 19.5, 5, 15, 6, 11, 8.5, 13.5, 10, 9, 12, 2], ox, oy, sz);
        } else if (name == :bolt) {
            _poly(dc, [13, 2, 3, 14, 12, 14, 11, 22, 21, 10, 12, 10, 13, 2], ox, oy, sz);
        } else if (name == :pulse) {
            _poly(dc, [2, 12, 5, 12, 7, 7, 11, 17, 14, 10, 16, 12, 22, 12], ox, oy, sz);
        } else if (name == :drop) {
            _poly(dc, [12, 2, 15, 7, 18.5, 11.5, 19, 15, 17, 19.5, 12, 22, 7, 19.5, 5, 15, 5.5, 11.5, 9, 7, 12, 2], ox, oy, sz);
        } else if (name == :battery) {
            dc.drawRoundedRectangle(sx(ox + 2 * f), sy(oy + 7 * f), s(16 * f), s(10 * f), s(2 * f));
            dc.drawLine(sx(ox + 21 * f), sy(oy + 11 * f), sx(ox + 21 * f), sy(oy + 13 * f));
        } else if (name == :sunrise || name == :sunset) {
            dc.drawArc(sx(cx), sy(oy + 18 * f), s(5 * f), Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
            dc.drawLine(sx(ox + 2 * f), sy(oy + 18 * f), sx(ox + 22 * f), sy(oy + 18 * f));
            if (name == :sunrise) {
                _poly(dc, [12, 9, 12, 2, 9, 5, 12, 2, 15, 5], ox, oy, sz);
            } else {
                _poly(dc, [12, 2, 12, 9, 9, 6, 12, 9, 15, 6], ox, oy, sz);
            }
        } else if (name == :bell) {
            _poly(dc, [6, 16, 6, 10, 8, 5, 12, 3, 16, 5, 18, 10, 18, 16, 20, 18, 4, 18, 6, 16], ox, oy, sz);
            dc.drawLine(sx(ox + 10 * f), sy(oy + 21 * f), sx(ox + 14 * f), sy(oy + 21 * f));
        } else if (name == :moon) {
            dc.drawArc(sx(cx), sy(cy), s(9 * f), Graphics.ARC_COUNTER_CLOCKWISE, 45, 315);
            dc.drawArc(sx(cx + 6 * f), sy(cy - 6 * f), s(7 * f), Graphics.ARC_CLOCKWISE, 160, 290);
        } else if (name == :sun) {
            dc.drawCircle(sx(cx), sy(cy), s(4 * f));
            for (var i = 0; i < 8; i++) {
                var a = i * 45;
                dc.drawLine(sx(px(cx, 7 * f, a)), sy(py(cy, 7 * f, a)), sx(px(cx, 10 * f, a)), sy(py(cy, 10 * f, a)));
            }
        } else if (name == :cloud) {
            _poly(dc, [6, 19, 17.5, 19, 20.5, 17, 21.5, 14, 20, 11, 17.5, 10, 15.5, 6.5, 11.5, 5, 7.5, 7, 6.5, 10.5, 3.5, 12, 2.5, 15.5, 4, 18, 6, 19], ox, oy, sz);
        } else if (name == :pin) {
            _poly(dc, [12, 22, 6, 14, 4.5, 10, 6, 5.5, 9, 3, 12, 2, 15, 3, 18, 5.5, 19.5, 10, 18, 14, 12, 22], ox, oy, sz);
            dc.drawCircle(sx(cx), sy(oy + 10 * f), s(3 * f));
        }
    }
}
