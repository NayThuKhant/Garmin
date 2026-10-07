import Toybox.Lang;
import Toybox.Math;
import Toybox.Graphics;

// Filled, colored data icons for AE · Meridian, drawn procedurally on a 24-unit grid
// (like the mockup's 24x24 SVG viewBoxes). Positions go through Gfx so they scale and shift.
module Icons {

    var _ox as Float = 0.0;
    var _oy as Float = 0.0;
    var _f as Float = 1.0;
    var _heart as Array<Numeric> or Null = null;

    // Icon font built from tools/icons/meridian.json (fonts.json "Icons"); set by the view.
    // Character for icon id n is chr(64 + n); battery levels are '0'..'4'.
    var font as Graphics.FontType or Null = null;
    var fontSm as Graphics.FontType or Null = null;   // same icons at 80% (used on the arcs)
    var small as Boolean = false;                       // draw with fontSm

    function X(v as Numeric) as Number { return Gfx.sx(_ox + v * _f); }
    function Y(v as Numeric) as Number { return Gfx.sy(_oy + v * _f); }
    function L(v as Numeric) as Number {
        var n = Gfx.s(v * _f);
        return n < 1 ? 1 : n;
    }

    function poly(dc as Graphics.Dc, p as Array<Numeric>) as Void {
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < p.size(); i += 2) {
            pts.add([X(p[i]), Y(p[i + 1])]);
        }
        dc.fillPolygon(pts);
    }

    function circ(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
        dc.fillCircle(X(x), Y(y), L(r));
    }

    function rrect(dc as Graphics.Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, r as Numeric) as Void {
        dc.fillRoundedRectangle(X(x), Y(y), L(w), L(h), L(r));
    }

    function line(dc as Graphics.Dc, x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, w as Numeric) as Void {
        dc.setPenWidth(L(w));
        dc.drawLine(X(x1), Y(y1), X(x2), Y(y2));
    }

    // Upper half disc centered (x,y), radius r.
    function dome(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
        var p = [] as Array<Numeric>;
        for (var i = 0; i <= 12; i++) {
            var a = Math.PI * i / 12;
            p.add(x - r * Math.cos(a));
            p.add(y - r * Math.sin(a));
        }
        poly(dc, p);
    }

    function cloud(dc as Graphics.Dc, x as Numeric, y as Numeric, k as Numeric) as Void {
        // cloud centered near (x, y), scale k (1 = 20 units wide)
        circ(dc, x - 4.5 * k, y + 1.5 * k, 3.6 * k);
        circ(dc, x + 0.5 * k, y - 1.5 * k, 5.4 * k);
        circ(dc, x + 5.5 * k, y + 1.2 * k, 4.0 * k);
        rrect(dc, x - 8 * k, y + 1.2 * k, 17.5 * k, 4.2 * k, 2 * k);
    }

    function heart(dc as Graphics.Dc) as Void {
        if (_heart == null) {
            var h = [] as Array<Numeric>;
            for (var t = 0; t < 28; t++) {
                var a = Math.PI * 2 * t / 28;
                var sn = Math.sin(a);
                h.add(12 + 10.5 * sn * sn * sn);
                h.add(11.2 - (8.2 * Math.cos(a) - 3.2 * Math.cos(2 * a) - 1.3 * Math.cos(3 * a) - 0.6 * Math.cos(4 * a)));
            }
            _heart = h;
        }
        poly(dc, _heart as Array<Numeric>);
    }

    // Draw icon `id` (MD.I_*) centered at design (cx, cy), size sz, color, on background bg.
    // lvl: fill level 0..1 for battery icons (null = 0.6).
    function draw(dc as Graphics.Dc, id as Number, cx as Numeric, cy as Numeric, sz as Numeric,
                  color as Number, bg as Number, lvl as Float or Null) as Void {
        if (font != null && sz >= 24 && id != MD.I_NONE) {
            var ch = (64 + id).toChar().toString();
            if (id == MD.I_BATTERY) {
                var l = lvl == null ? 0.6 : (lvl as Float);
                ch = Math.round(l * 4).toNumber().toString();
            }
            var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
            var x = Gfx.sx(cx);
            var y = Gfx.sy(cy);
            var f = (small && fontSm != null) ? fontSm as Graphics.FontType : font as Graphics.FontType;
            // Background-colored halo so an icon sitting on its arc stays readable (as in the reference).
            var h = Gfx.s(2.5);
            if (h < 1) { h = 1; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            for (var k = 0; k < 8; k++) {
                var a = Math.PI * k / 4;
                dc.drawText(x + Math.round(h * Math.cos(a)).toNumber(), y + Math.round(h * Math.sin(a)).toNumber(), f, ch, j);
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, f, ch, j);
            return;
        }
        _f = (sz / 24.0).toFloat();
        _ox = (cx - sz / 2.0).toFloat();
        _oy = (cy - sz / 2.0).toFloat();
        if (lvl == null) { lvl = 0.6; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (id == MD.I_FOOT) {
            // two footprints with toes (mockup)
            dc.fillEllipse(X(7.6), Y(10.5), L(3.1), L(4.6));
            circ(dc, 5.2, 4.6, 1.1);
            circ(dc, 7.4, 3.9, 1.15);
            circ(dc, 9.6, 4.3, 1.1);
            rrect(dc, 5.3, 15.6, 4.6, 3.4, 1.7);
            dc.fillEllipse(X(16.6), Y(8.5), L(3.1), L(4.6));
            circ(dc, 14.2, 2.6, 1.1);
            circ(dc, 16.4, 1.9, 1.15);
            circ(dc, 18.6, 2.3, 1.1);
            rrect(dc, 14.3, 13.6, 4.6, 3.4, 1.7);
        } else if (id == MD.I_TARGET) {
            circ(dc, 12, 12, 10.5);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            circ(dc, 12, 12, 7.5);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            circ(dc, 12, 12, 4.5);
        } else if (id == MD.I_PIN) {
            circ(dc, 12, 9, 7);
            poly(dc, [5.6, 11.5, 12, 22.5, 18.4, 11.5]);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            circ(dc, 12, 9, 2.7);
        } else if (id == MD.I_FLAME) {
            poly(dc, [12, 1.5, 14.5, 6, 18, 9.5, 19.5, 14, 18, 18.5, 12, 22.5, 6, 18.5, 4.5, 14, 6, 9.5, 8.5, 12.5, 9.5, 7]);
        } else if (id == MD.I_STOPWATCH) {
            circ(dc, 12, 13.5, 8.8);
            rrect(dc, 9.5, 1.5, 5, 2.6, 1);
            line(dc, 12, 3, 12, 5, 2);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            line(dc, 12, 13.5, 12, 8, 2.2);
            line(dc, 12, 13.5, 15.5, 15.5, 2.2);
        } else if (id == MD.I_HEART) {
            heart(dc);
            line(dc, 4, 19.5, 1.5, 22, 2.6);
        } else if (id == MD.I_BODY) {
            dc.setPenWidth(L(2));
            dc.drawRoundedRectangle(X(7), Y(4), L(10), L(18), L(2));
            dc.fillRectangle(X(10), Y(2), L(4), L(2.5));
            var h = 14 * (lvl as Float);
            if (h >= 1) { dc.fillRectangle(X(9), Y(20 - h), L(6), L(h)); }
        } else if (id == MD.I_STRESS) {
            circ(dc, 11.5, 13.5, 8.5);
            line(dc, 17.5, 4, 19, 1.5, 1.6);
            line(dc, 20, 6.5, 22.5, 5, 1.6);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(L(1.6));
            dc.drawArc(X(11.5), Y(13.5), L(5.2), Graphics.ARC_COUNTER_CLOCKWISE, 0, 280);
            dc.drawArc(X(11.5), Y(13.5), L(2.4), Graphics.ARC_COUNTER_CLOCKWISE, 90, 360);
        } else if (id == MD.I_O2 || id == MD.I_DROP) {
            circ(dc, 12, 15, 6.6);
            poly(dc, [12, 1.5, 5.8, 13, 18.2, 13]);
            if (id == MD.I_O2) {
                dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(L(1.6));
                dc.drawCircle(X(12), Y(15.5), L(2.8));
            }
        } else if (id == MD.I_LUNGS) {
            dc.fillEllipse(X(7.5), Y(14), L(4.8), L(7.5));
            dc.fillEllipse(X(16.5), Y(14), L(4.8), L(7.5));
            rrect(dc, 10.8, 1.5, 2.4, 10, 1.2);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            line(dc, 12, 9, 12, 23, 1.6);
        } else if (id == MD.I_BATTERY) {
            dc.setPenWidth(L(2));
            dc.drawRoundedRectangle(X(1.5), Y(6.5), L(19), L(11), L(2));
            dc.fillRectangle(X(21), Y(9.5), L(2), L(5));
            var w = 14 * (lvl as Float);
            if (w >= 1) { dc.fillRectangle(X(4), Y(9), L(w), L(6)); }
        } else if (id == MD.I_BOLT) {
            circ(dc, 12, 12, 11.5);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            poly(dc, [13.2, 4.5, 7, 13.4, 11.6, 13.4, 10.6, 19.5, 17, 10.3, 12.3, 10.3]);
        } else if (id == MD.I_THERMO) {
            rrect(dc, 9.3, 1.5, 5.4, 15, 2.7);
            circ(dc, 12, 18, 4.6);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            line(dc, 12, 5, 12, 15, 1.4);
        } else if (id == MD.I_SUN) {
            circ(dc, 12, 12, 5);
            dc.setPenWidth(L(2));
            for (var i = 0; i < 8; i++) {
                var a = Math.PI * i / 4;
                dc.drawLine(X(12 + 7.5 * Math.cos(a)), Y(12 + 7.5 * Math.sin(a)),
                            X(12 + 10.5 * Math.cos(a)), Y(12 + 10.5 * Math.sin(a)));
            }
        } else if (id == MD.I_PARTLY) {
            // sun behind a cloud, ray wedges (mockup)
            poly(dc, [9.5, 1.5, 10.3, 3.8, 8.7, 3.8]);
            poly(dc, [3.3, 3.6, 5.5, 4.6, 4.3, 5.8]);
            poly(dc, [15.7, 3.6, 14.7, 5.8, 13.5, 4.6]);
            poly(dc, [1, 9.8, 3.3, 9, 3.3, 10.6]);
            circ(dc, 9.4, 9.6, 3.9);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            circ(dc, 13.2, 15.6, 7.2);
            circ(dc, 6.8, 18.9, 4.8);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            circ(dc, 13.2, 15.6, 6);
            circ(dc, 17.7, 17.9, 4.6);
            circ(dc, 6.8, 18.9, 3.6);
            dc.fillRectangle(X(6.8), Y(17), L(11), L(5.5));
        } else if (id == MD.I_CLOUD) {
            cloud(dc, 12, 12, 1.0);
        } else if (id == MD.I_RAIN || id == MD.I_SNOW || id == MD.I_STORM) {
            cloud(dc, 12, 8.5, 0.95);
            if (id == MD.I_RAIN) {
                line(dc, 7, 17.5, 5.5, 21.5, 1.8);
                line(dc, 12, 17.5, 10.5, 21.5, 1.8);
                line(dc, 17, 17.5, 15.5, 21.5, 1.8);
            } else if (id == MD.I_SNOW) {
                circ(dc, 7, 19, 1.5);
                circ(dc, 12, 21, 1.5);
                circ(dc, 17, 19, 1.5);
            } else {
                poly(dc, [13, 15, 8.5, 20, 11.5, 20, 10, 23.5, 15.5, 18, 12.5, 18, 14, 15]);
            }
        } else if (id == MD.I_UMBRELLA) {
            dome(dc, 12, 12, 10);
            line(dc, 12, 11, 12, 19.5, 2);
            dc.setPenWidth(L(2));
            dc.drawArc(X(9.75), Y(19.5), L(2.25), Graphics.ARC_CLOCKWISE, 0, 180);
        } else if (id == MD.I_WIND) {
            line(dc, 2, 8, 15, 8, 2.2);
            line(dc, 2, 12.5, 19, 12.5, 2.2);
            line(dc, 2, 17, 12, 17, 2.2);
            dc.setPenWidth(L(2.2));
            dc.drawArc(X(15), Y(5.5), L(2.5), Graphics.ARC_COUNTER_CLOCKWISE, 180, 270);
            dc.drawArc(X(19), Y(10), L(2.5), Graphics.ARC_COUNTER_CLOCKWISE, 180, 270);
        } else if (id == MD.I_SUNRISE || id == MD.I_SUNSET) {
            if (id == MD.I_SUNRISE) {
                poly(dc, [12, 1, 8.4, 5.4, 10.8, 5.4, 10.8, 9.6, 13.2, 9.6, 13.2, 5.4, 15.6, 5.4]);
            } else {
                poly(dc, [12, 9.6, 8.4, 5.2, 10.8, 5.2, 10.8, 1, 13.2, 1, 13.2, 5.2, 15.6, 5.2]);
            }
            dome(dc, 12, 18.6, 5.8);
            rrect(dc, 1.5, 19.4, 21, 2.4, 1.2);
            poly(dc, [12, 10.4, 12.9, 12.3, 11.1, 12.3]);
            poly(dc, [5.4, 12.4, 7.3, 13.3, 6.1, 14.6]);
            poly(dc, [18.6, 12.4, 16.7, 13.3, 17.9, 14.6]);
            poly(dc, [2.2, 16.6, 4.4, 16.9, 3.6, 18.5]);
            poly(dc, [21.8, 16.6, 19.6, 16.9, 20.4, 18.5]);
            poly(dc, [8.2, 10.9, 9.6, 12.4, 7.9, 13.0]);
            poly(dc, [15.8, 10.9, 14.4, 12.4, 16.1, 13.0]);
        } else if (id == MD.I_BELL) {
            circ(dc, 12, 3.5, 1.7);
            poly(dc, [12, 4, 15.4, 5.2, 17.8, 7.8, 18.8, 10.7, 18.8, 15.3, 21.2, 18.1, 21.2, 19.3, 2.8, 19.3,
                      2.8, 18.1, 5.2, 15.3, 5.2, 10.7, 6.2, 7.8, 8.6, 5.2]);
            circ(dc, 12, 20.4, 2.8);
        } else if (id == MD.I_ALARM) {
            circ(dc, 12, 13, 8.5);
            circ(dc, 4.5, 5, 2.8);
            circ(dc, 19.5, 5, 2.8);
            line(dc, 6.5, 19.5, 4.5, 22, 2);
            line(dc, 17.5, 19.5, 19.5, 22, 2);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            line(dc, 12, 13, 12, 8, 2);
            line(dc, 12, 13, 15.5, 15, 2);
        } else if (id == MD.I_PHONE) {
            rrect(dc, 6.5, 1.5, 11, 21, 2.5);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(X(8.5), Y(4.5), L(7), L(13));
            circ(dc, 12, 20, 1);
        } else if (id == MD.I_CALENDAR) {
            rrect(dc, 2.5, 4, 19, 18, 2.2);
            rrect(dc, 6, 1.5, 2.4, 5, 1.2);
            rrect(dc, 15.6, 1.5, 2.4, 5, 1.2);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(X(2.5), Y(8.2), L(19), L(1.4));
            for (var r = 0; r < 2; r++) {
                for (var c = 0; c < 3; c++) {
                    dc.fillRectangle(X(5.5 + 5 * c), Y(11.5 + 4.5 * r), L(3), L(2.6));
                }
            }
        } else if (id == MD.I_MOUNTAIN) {
            poly(dc, [1, 21, 9, 6, 13.5, 13, 16.5, 9, 23, 21]);
        } else if (id == MD.I_RECOVERY) {
            circ(dc, 12, 12, 7.5);
            dc.setPenWidth(L(1.8));
            for (var i = 0; i < 8; i++) {
                var a = i * 45 + 10;
                dc.drawArc(X(12), Y(12), L(10.5), Graphics.ARC_COUNTER_CLOCKWISE, a, a + 26);
            }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(X(10.8), Y(7.5), L(2.4), L(9));
            dc.fillRectangle(X(7.5), Y(10.8), L(9), L(2.4));
        } else if (id == MD.I_TREND) {
            dc.setPenWidth(L(2.6));
            dc.drawLine(X(2), Y(19), X(9), Y(12));
            dc.drawLine(X(9), Y(12), X(13), Y(16));
            dc.drawLine(X(13), Y(16), X(19), Y(10));
            poly(dc, [22, 4.5, 14, 4.5, 22, 12.5]);
        } else if (id == MD.I_GAUGE || id == MD.I_BARO) {
            if (id == MD.I_GAUGE) {
                dome(dc, 12, 17, 10.5);
                dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
                dome(dc, 12, 17.5, 7);
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                line(dc, 12, 17, 17, 9.5, 2.2);
                circ(dc, 12, 17, 2.4);
            } else {
                circ(dc, 12, 12, 10.5);
                dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
                circ(dc, 12, 12, 8);
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                line(dc, 12, 12, 16.5, 7, 2.2);
                circ(dc, 12, 12, 2.2);
            }
        } else if (id == MD.I_MOON) {
            circ(dc, 12, 12, 9.5);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            circ(dc, 16.5, 8, 8);
        } else if (id == MD.I_STAIRS) {
            poly(dc, [2, 21.5, 2, 17, 7, 17, 7, 12.5, 12, 12.5, 12, 8, 17, 8, 17, 3.5, 22, 3.5, 22, 21.5]);
        }
    }
}
