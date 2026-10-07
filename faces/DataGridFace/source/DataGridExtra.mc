import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Face-local helpers (not part of the shared Data/Gfx modules).
module Ex {

    // Color property `id` from settings, falling back to `def`.
    function color(id as String, def as Number) as Number {
        var v = Application.Properties.getValue(id);
        return v instanceof Number ? v : def;
    }

    // v / max clamped to 0..1; 0 when either is missing.
    function frac(v as Numeric or Null, max as Numeric or Null) as Float {
        if (v == null || max == null || max <= 0) { return 0.0; }
        var f = v.toFloat() / max;
        return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
    }

    // Arc in clock degrees (any order) with round caps.
    function capArc(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric,
                    a0 as Numeric, a1 as Numeric, color as Number, w as Numeric) as Void {
        if (a1 < a0) { var t = a0; a0 = a1; a1 = t; }
        Gfx.arc(dc, cx, cy, r, a0, a1, color, w);
        var rad = Gfx.s(w) / 2.0;
        if (rad < 0.5) { return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(Gfx.px(cx, r, a0)), Gfx.sy(Gfx.py(cy, r, a0)), rad);
        dc.fillCircle(Gfx.sx(Gfx.px(cx, r, a1)), Gfx.sy(Gfx.py(cy, r, a1)), rad);
    }

    // Track arc from a0 towards a1 (clock degrees, either direction) filled to `f` (0..1).
    function gauge(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric, a0 as Numeric, a1 as Numeric,
                   f as Float, track as Number or Null, color as Number, w as Numeric) as Void {
        if (track != null) {
            capArc(dc, cx, cy, r, a0, a1, track, w);
        }
        if (f > 0.004) {
            capArc(dc, cx, cy, r, a0, a0 + (a1 - a0) * f, color, w);
        }
    }

    // Several text pieces in a row (one font, letter-spacing baked in), centered at cx,
    // caps centered at y.
    function pieces(dc as Graphics.Dc, cx as Numeric, y as Numeric, f as Graphics.FontType,
                    strs as Array<String>, colors as Array<Number>) as Void {
        var total = 0.0;
        for (var i = 0; i < strs.size(); i++) {
            total += Gfx.width(dc, strs[i], f);
        }
        var x = cx - total / 2;
        for (var i = 0; i < strs.size(); i++) {
            Gfx.text(dc, x, y, f, strs[i], colors[i], Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, strs[i], f);
        }
    }

    // Row of [icon, gap, text] groups centered at cx, y. icons[i] may be null (text only).
    function iconRow(dc as Graphics.Dc, cx as Numeric, y as Numeric, f as Graphics.FontType,
                     icons as Array, sizes as Array<Numeric>, iconColors as Array<Number>,
                     texts as Array<String>, textColors as Array<Number>,
                     inner as Numeric, outer as Numeric) as Void {
        var n = texts.size();
        var total = outer * (n - 1);
        for (var i = 0; i < n; i++) {
            total += Gfx.width(dc, texts[i], f);
            if (icons[i] != null) { total += sizes[i] + inner; }
        }
        var x = cx - total / 2.0;
        for (var i = 0; i < n; i++) {
            if (icons[i] != null) {
                Gfx.icon(dc, icons[i] as Symbol, x + sizes[i] / 2.0, y, sizes[i], iconColors[i]);
                x += sizes[i] + inner;
            }
            Gfx.text(dc, x, y, f, texts[i], textColors[i], Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, texts[i], f) + outer;
        }
    }

    // Weather condition -> :sun / :moon / :cloud.
    function weatherIcon() as Symbol {
        var c = Data.condition();
        if (c != null && (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR
                || c == Weather.CONDITION_FAIR)) {
            var h = System.getClockTime().hour;
            return (h >= 6 && h < 19) ? :sun : :moon;
        }
        return :cloud;
    }

    function tempStr() as String {
        var t = Data.temperature();
        return t != null ? t + "°" : "--°";
    }

    // "MONDAY 05 OCT"
    function longDateStr() as String {
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Data.weekday() + " " + m.day.format("%02d") + " " + (m.month as String).toUpper();
    }

    function minStr() as String {
        return (System.getClockTime().min as Number).format("%02d");
    }

    function secStr() as String {
        return (System.getClockTime().sec as Number).format("%02d");
    }

    // Estimated battery days left, or null.
    function batteryDays() as Number or Null {
        var st = System.getSystemStats();
        if ((st has :batteryInDays) && st.batteryInDays != null) {
            return (st.batteryInDays as Numeric).toNumber();
        }
        return null;
    }
}
