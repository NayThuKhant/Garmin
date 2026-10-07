import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face AB · Segment — mockups/Segment.dc.html (active), mockups/SegmentAOD.dc.html (always-on).
// Seven-segment time drawn as hexagonal bars (digit 56x108, bar 11, gap 1.5).
class SegmentView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    const GHOST = 0x141414;
    const AOD = 0x6A6A6A;

    // Digit left edges (design px); all digits start at y 136.
    const DIGIT_X = [58, 126, 220, 288];
    const DIGIT_Y = 136;

    // Segments a,b,c,d,e,f,g as hexagons (x,y pairs relative to the digit's top-left).
    const SEGS = [
        [1.5, 5.5, 7, 0, 49, 0, 54.5, 5.5, 49, 11, 7, 11],               // a top
        [50.5, 1.5, 56, 7, 56, 47, 50.5, 52.5, 45, 47, 45, 7],           // b upper right
        [50.5, 55.5, 56, 61, 56, 101, 50.5, 106.5, 45, 101, 45, 61],     // c lower right
        [1.5, 102.5, 7, 97, 49, 97, 54.5, 102.5, 49, 108, 7, 108],       // d bottom
        [5.5, 55.5, 11, 61, 11, 101, 5.5, 106.5, 0, 101, 0, 61],         // e lower left
        [5.5, 1.5, 11, 7, 11, 47, 5.5, 52.5, 0, 47, 0, 7],               // f upper left
        [1.5, 54, 7, 48.5, 49, 48.5, 54.5, 54, 49, 59.5, 7, 59.5]        // g middle
    ];

    // Lit segments per digit 0-9, bit i = SEGS[i].
    const DIGITS = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F];

    var fDate as FontResource;
    var fSteps as FontResource;
    var fInfo as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fSteps = WatchUi.loadResource(Rez.Fonts.Steps) as FontResource;
        fInfo = WatchUi.loadResource(Rez.Fonts.Info) as FontResource;
    }

    function onEnterSleep() as Void {
        mSleep = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mSleep = false;
        WatchUi.requestUpdate();
    }

    // Device points of segment `si` of the digit at (x0, y0).
    function segPoints(si as Number, x0 as Numeric, y0 as Numeric) as Array<[Numeric, Numeric]> {
        var p = SEGS[si] as Array<Numeric>;
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < 12; i += 2) {
            pts.add([Gfx.sx(x0 + p[i]), Gfx.sy(y0 + p[i + 1])]);
        }
        return pts;
    }

    // Digit d (0-9, or -1 = blank). Active: lit accent + ghost segments; AOD: outlines of lit segments.
    function drawDigit(dc as Dc, idx as Number, d as Number, color as Number, aod as Boolean) as Void {
        var x0 = DIGIT_X[idx] as Number;
        var mask = d < 0 ? 0 : DIGITS[d] as Number;
        for (var si = 0; si < 7; si++) {
            var on = (mask & (1 << si)) != 0;
            if (aod) {
                if (!on) { continue; }
                var pts = segPoints(si, x0, DIGIT_Y);
                for (var i = 0; i < 6; i++) {
                    var a = pts[i];
                    var b = pts[(i + 1) % 6];
                    dc.drawLine(a[0], a[1], b[0], b[1]);
                }
            } else {
                dc.setColor(on ? color : GHOST, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon(segPoints(si, x0, DIGIT_Y));
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        Gfx.setup(dc);
        if (mSleep) {
            Gfx.aodShift();
        }
        var aod = mSleep;
        var acc = Gfx.accent(0xFF6A3D);

        // Time digits.
        var t = Data.clock();
        var h = t.hour as Number;
        var min = t.min as Number;
        var lead = h / 10;
        if (!Data.is24()) {
            h = h % 12;
            if (h == 0) { h = 12; }
            lead = h >= 10 ? 1 : -1;
        }
        var digits = [lead, h % 10, min / 10, min % 10];
        if (aod) {
            dc.setColor(AOD, Graphics.COLOR_TRANSPARENT);
            var pw = Gfx.s(1.5);
            dc.setPenWidth(pw < 1 ? 1 : pw);
        }
        for (var i = 0; i < 4; i++) {
            drawDigit(dc, i, digits[i] as Number, acc, aod);
        }

        // Colon.
        if (aod) {
            var sz = Gfx.s(9);
            dc.drawRectangle(Gfx.sx(197.5), Gfx.sy(166.1), sz, sz);
            dc.drawRectangle(Gfx.sx(197.5), Gfx.sy(204.9), sz, sz);
        } else {
            Gfx.rect(dc, 197, 165.6, 10, 10, acc);
            Gfx.rect(dc, 197, 204.4, 10, 10, acc);
        }

        // Date line: top 92, 13px, ls 3; temperature after a 10px margin (active only).
        var date = dateStr();
        if (aod) {
            Gfx.text(dc, 195, 100.5, fDate, date, 0x5A5A5A, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var temp = Data.temperature();
            var ts = (temp != null ? temp.toString() : "--") + "°" + (isStatute() ? "F" : "C");
            var gap = Gfx.width(dc, " ", fDate) + 10;
            var wd = Gfx.width(dc, date, fDate);
            var x = 195 - (wd + gap + Gfx.width(dc, ts, fDate)) / 2;
            Gfx.text(dc, x, 100.5, fDate, date, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
            Gfx.text(dc, x + wd + gap, 100.5, fDate, ts, 0x4A4A4A, Graphics.TEXT_JUSTIFY_LEFT);
        }

        var hr = Data.fmt(Data.heartRate());
        var bb = Data.fmt(Data.bodyBattery());
        if (aod) {
            // HR / BB at top 278, gap 16.
            var parts = ["HR " + hr, "BB " + bb];
            var total = 16 + Gfx.width(dc, parts[0], fInfo) + Gfx.width(dc, parts[1], fInfo);
            var x = 195 - total / 2;
            Gfx.text(dc, x, 286.5, fInfo, parts[0], AOD, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[0], fInfo) + 16;
            Gfx.text(dc, x, 286.5, fInfo, parts[1], AOD, Graphics.TEXT_JUSTIFY_LEFT);
            Gfx.aodMask(dc);
            return;
        }

        // Steps bar: 20 cells 7x7, pitch 9.5, from x 103 at y 262.
        var steps = Data.steps();
        var goal = Data.stepGoal();
        var n = 0;
        if (steps != null && goal != null && goal > 0) {
            n = steps * 20 / goal;
            if (n > 20) { n = 20; }
        }
        var cell = Gfx.s(7);
        for (var i = 0; i < 20; i++) {
            dc.setColor(i < n ? acc : 0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(Gfx.sx(103 + 9.5 * i), Gfx.sy(262), cell, cell);
        }
        Gfx.text(dc, 195, 284.5, fSteps, "STEPS " + Data.thousands(steps) + " / " + goalStr(goal),
                 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);

        // HR / BB / BAT: 13px, labels #5A5A5A, values #D0D0D0, gap 16, top 300.
        var labels = ["HR", "BB", "BAT"];
        var values = [" " + hr, " " + bb, " " + Data.battery() + "%"];
        var total = 32.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, labels[i], fInfo) + Gfx.width(dc, values[i], fInfo);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 308.5, fInfo, labels[i], 0x5A5A5A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, labels[i], fInfo);
            Gfx.text(dc, x, 308.5, fInfo, values[i], 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, values[i], fInfo) + 16;
        }
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }

    function isStatute() as Boolean {
        return System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE;
    }

    // "MON 05·10" (weekday, day, month number).
    function dateStr() as String {
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var s = Data.clock();
        return (m.day_of_week as String).toUpper() + " " + (m.day as Number).format("%02d") + "·" + (s.month as Number).format("%02d");
    }

    // 10000 -> "10K", 7500 -> "7,500".
    function goalStr(g as Number or Null) as String {
        if (g == null) { return "--"; }
        if (g >= 1000 && g % 1000 == 0) { return (g / 1000).toString() + "K"; }
        return Data.thousands(g);
    }
}
