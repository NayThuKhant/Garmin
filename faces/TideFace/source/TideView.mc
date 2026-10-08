import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face O · Tide — mockups/Tide.dc.html (active), mockups/TideAOD.dc.html (always-on).
class TideView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (faces/TideFace/fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fDate as FontResource;
    var fHead as FontResource;
    var fAod as FontResource;
    var fValue as FontResource;
    var fTag as FontResource;
    var fLabel as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fAod = WatchUi.loadResource(Rez.Fonts.Aod) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fTag = WatchUi.loadResource(Rez.Fonts.Tag) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
    }

    function onEnterSleep() as Void {
        mSleep = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mSleep = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        Gfx.setup(dc);
        if (mSleep) {
            Gfx.aodShift();
            drawAod(dc);
        } else {
            drawActive(dc);
        }
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }

    // Sine wave y(x) = c + a*cos(2pi(x - x0)/p), in design units.
    function waveY(x as Numeric, c as Float, a as Float, p as Float, x0 as Float) as Float {
        return (c + a * Math.cos(2 * Math.PI * (x - x0) / p)).toFloat();
    }

    // Fill everything below the wave with `color`. Filled in vertical chunks without
    // anti-aliasing (no seams), then the crest is stroked anti-aliased.
    function fillWave(dc as Dc, c as Float, a as Float, p as Float, x0 as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var aa = dc has :setAntiAlias;
        if (aa) { dc.setAntiAlias(false); }
        var step = 6;
        var seg = 8;
        for (var x = 0; x < 390; x += step * seg) {
            var pts = [] as Array<[Numeric, Numeric]>;
            var xe = x + step * seg;
            if (xe > 390) { xe = 390; }
            for (var xi = x; xi <= xe; xi += step) {
                pts.add([Gfx.sx(xi), Gfx.sy(waveY(xi, c, a, p, x0))]);
            }
            pts.add([Gfx.sx(xe), Gfx.sy(392)]);
            pts.add([Gfx.sx(x), Gfx.sy(392)]);
            dc.fillPolygon(pts);
        }
        if (aa) { dc.setAntiAlias(true); }
        strokeWave(dc, c, a, p, x0, color, 1);
    }

    function strokeWave(dc as Dc, c as Float, a as Float, p as Float, x0 as Float, color as Number, w as Numeric) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pw = Gfx.s(w);
        dc.setPenWidth(pw < 1 ? 1 : pw);
        var step = 6;
        var yPrev = waveY(0, c, a, p, x0);
        for (var x = step; x <= 390; x += step) {
            var y = waveY(x, c, a, p, x0);
            dc.drawLine(Gfx.sx(x - step), Gfx.sy(yPrev), Gfx.sx(x), Gfx.sy(y));
            yPrev = y;
        }
    }

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    // "MONDAY 05 OCT"
    function longDate() as String {
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Data.weekday() + " " + (m.day as Number).format("%02d") + " " + (m.month as String).toUpper();
    }

    function drawArrow(dc as Dc, cx as Float, cy as Numeric, up as Boolean, color as Number) as Void {
        var tip = up ? cy - 4.5 : cy + 4.5;
        var tail = up ? cy + 4.5 : cy - 4.5;
        var wing = up ? tip + 3 : tip - 3;
        Gfx.line(dc, cx, tail, cx, tip, color, 1.2);
        Gfx.line(dc, cx - 2.6, wing, cx, tip, color, 1.2);
        Gfx.line(dc, cx + 2.6, wing, cx, tip, color, 1.2);
    }

    function drawActive(dc as Dc) as Void {
        // Accent (setting): body tag + grid labels.
        var label = Gfx.accent(0x8FB7E0);
        fillWave(dc, 120.8, 7.0, 156.0, 12.0, Gfx.dim(0x0E3A66, 0.55));
        fillWave(dc, 124.8, 6.0, 132.0, 30.0, 0x0A2E52);
        fillWave(dc, 170.8, 4.0, 108.0, 102.0, 0x08243F);

        // Header: date (12px, ls 3) and temp/sun line, column from top 52, gap 2.
        var f12 = fHead;
        Gfx.text(dc, 195, 59.2, fDate, longDate(), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);
        var temp = Data.temperature();
        var t0 = (temp != null ? temp + "°" : "--°") + " · ";
        var rise = Data.timeOf(Data.sunrise());
        var set = Data.timeOf(Data.sunset());
        var aw = 7;
        var total = Gfx.width(dc, t0, f12) + aw + 1 + Gfx.width(dc, rise, f12) + 4 + aw + 1 + Gfx.width(dc, set, f12);
        var x = 195 - total / 2;
        var y = 75.6;
        var col = 0xD0D0D0;
        Gfx.text(dc, x, y, f12, t0, col, Graphics.TEXT_JUSTIFY_LEFT);
        x += Gfx.width(dc, t0, f12);
        drawArrow(dc, x + aw / 2.0, y, true, col);
        x += aw + 1;
        Gfx.text(dc, x, y, f12, rise, col, Graphics.TEXT_JUSTIFY_LEFT);
        x += Gfx.width(dc, rise, f12) + 4;
        drawArrow(dc, x + aw / 2.0, y, false, col);
        x += aw + 1;
        Gfx.text(dc, x, y, f12, set, col, Graphics.TEXT_JUSTIFY_LEFT);

        // Body battery tag above the swell.
        Gfx.text(dc, 286, 104, fTag, "BODY " + Data.fmt(Data.bodyBattery()), label, Graphics.TEXT_JUSTIFY_LEFT);

        // Time: 96px, line-height 1, top 140.
        Gfx.text(dc, 195, 188, fTime, timeStr(), 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);

        // 3x2 grid from top 254, columns centred at 111.7 / 195 / 278.3.
        var o2 = Data.spo2();
        var values = [
            Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), Data.fmt(Data.stress()),
            Data.thousands(Data.calories()), o2 != null ? o2 + "%" : "--", Data.battery() + "%"
        ];
        var labels = ["BPM", "STEPS", "STRESS", "KCAL", "SPO2", "BATT"];
        var vf = fValue;
        var lf = fLabel;
        for (var i = 0; i < 6; i++) {
            var cx = 111.67 + 83.33 * (i % 3);
            var top = 254 + 39.2 * (i / 3);
            Gfx.text(dc, cx, top + 10.2, vf, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, top + 25.8, lf, labels[i] as String, label, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawAod(dc as Dc) as Void {
        strokeWave(dc, 124.8, 6.0, 132.0, 30.0, 0x1E4A7A, 2);
        Gfx.text(dc, 195, 77.2, fDate, longDate(), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 188, fTime, timeStr(), 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);

        var f = fAod;
        var parts = ["HR " + Data.fmt(Data.heartRate()), "BB " + Data.fmt(Data.bodyBattery()), Data.battery() + "%"];
        var total = 32.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i] as String, f);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 269.8, f, parts[i] as String, 0x6A6A6A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, f) + 16;
        }
    }
}
