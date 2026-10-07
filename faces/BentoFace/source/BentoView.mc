import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Weather;
import Toybox.WatchUi;

// Face AC · Bento — mockups/Bento.dc.html (active), mockups/BentoAOD.dc.html (always-on).
class BentoView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    const TILE = 0x121212;
    const HR_RED = 0xFF6B5A;
    const BLUE = 0x4DA3FF;
    const GREY = 0x7A7A7A;
    const SPARK_N = 11;

    var fTime as FontResource;
    var fTimeAod as FontResource;
    var fDate as FontResource;
    var fDateAod as FontResource;
    var fNotif as FontResource;
    var fSteps as FontResource;
    var fTag as FontResource;
    var fHr as FontResource;
    var fTemp as FontResource;
    var fSmall as FontResource;
    var fAod as FontResource;

    // HR sparkline cache, refreshed once a minute: SPARK_N averaged points + day range.
    var mHrMin as Number = -1;
    var mSpark as Array<Float> or Null = null;
    var mHrLo as Number or Null = null;
    var mHrHi as Number or Null = null;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fDateAod = WatchUi.loadResource(Rez.Fonts.DateAod) as FontResource;
        fNotif = WatchUi.loadResource(Rez.Fonts.Notif) as FontResource;
        fSteps = WatchUi.loadResource(Rez.Fonts.Steps) as FontResource;
        fTag = WatchUi.loadResource(Rez.Fonts.Tag) as FontResource;
        fHr = WatchUi.loadResource(Rez.Fonts.Hr) as FontResource;
        fTemp = WatchUi.loadResource(Rez.Fonts.Temp) as FontResource;
        fSmall = WatchUi.loadResource(Rez.Fonts.Small) as FontResource;
        fAod = WatchUi.loadResource(Rez.Fonts.Aod) as FontResource;
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

    // ---- helpers ----

    function tile(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(Gfx.sx(x), Gfx.sy(y), Gfx.s(w), Gfx.s(h), Gfx.s(22));
    }

    function outline(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric) as Void {
        dc.setColor(0x1C1C1C, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(Gfx.sx(x), Gfx.sy(y), Gfx.s(w), Gfx.s(h), Gfx.s(22));
    }

    // Progress bar with rounded ends; pct 0..1.
    function bar(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric,
                 pct as Float, track as Number, fill as Number) as Void {
        var r = Gfx.s(h / 2.0);
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(Gfx.sx(x), Gfx.sy(y), Gfx.s(w), Gfx.s(h), r);
        if (pct <= 0) { return; }
        if (pct > 1) { pct = 1.0; }
        var fw = Gfx.s(w * pct);
        if (fw < Gfx.s(h)) { fw = Gfx.s(h); }
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(Gfx.sx(x), Gfx.sy(y), fw, Gfx.s(h), r);
    }

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    // 7412 -> "7.4k", 812 -> "812"
    function stepsStr() as String {
        var n = Data.steps();
        if (n == null) { return "--"; }
        if (n < 1000) { return n.toString(); }
        return (n / 1000).toString() + "." + ((n % 1000) / 100).toString() + "k";
    }

    function stepsPct() as Float {
        var n = Data.steps();
        var g = Data.stepGoal();
        if (n == null || g == null || g <= 0) { return 0.0; }
        return n.toFloat() / g;
    }

    // Today's high/low from Weather, in the user's unit.
    function highLow() as String {
        if (!(Toybox has :Weather)) { return "H -- · L --"; }
        var c = Weather.getCurrentConditions();
        if (c == null) { return "H -- · L --"; }
        return "H " + tempStr(c.highTemperature) + " · L " + tempStr(c.lowTemperature);
    }

    function tempStr(t) as String {
        if (t == null) { return "--"; }
        var v = (t as Numeric).toFloat();
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            v = v * 9.0 / 5.0 + 32;
        }
        return Math.round(v).toNumber().toString();
    }

    function isSunny(c as Number or Null) as Boolean {
        if (c == null) { return true; }
        return c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR
            || c == Weather.CONDITION_PARTLY_CLEAR || c == Weather.CONDITION_FAIR;
    }

    // Rebuild the HR sparkline once a minute from the stored HR history.
    function refreshHr() as Void {
        var m = System.getClockTime().min;
        if (m == mHrMin && mSpark != null) { return; }
        mHrMin = m;
        var hist = Data.hrHistory(120);
        var n = hist.size();
        mSpark = null;
        mHrLo = null;
        mHrHi = null;
        if (n == 0) { return; }
        var lo = hist[0];
        var hi = hist[0];
        for (var i = 1; i < n; i++) {
            if (hist[i] < lo) { lo = hist[i]; }
            if (hist[i] > hi) { hi = hist[i]; }
        }
        mHrLo = lo;
        mHrHi = hi;
        if (n < 2) { return; }
        var pts = [] as Array<Float>;
        for (var b = 0; b < SPARK_N; b++) {
            var a = b * n / SPARK_N;
            var e = (b + 1) * n / SPARK_N;
            if (e <= a) { e = a + 1; }
            var sum = 0;
            for (var i = a; i < e; i++) { sum += hist[i]; }
            pts.add(sum.toFloat() / (e - a));
        }
        mSpark = pts;
    }

    // Sparkline in the 70x22 box at (160, 228): values mapped to y 4..16, stroke 2.
    function drawSpark(dc as Dc) as Void {
        var pts = mSpark;
        var ox = 160;
        var oy = 228;
        dc.setColor(HR_RED, Graphics.COLOR_TRANSPARENT);
        var pw = Gfx.s(2);
        dc.setPenWidth(pw < 1 ? 1 : pw);
        if (pts == null) {
            dc.drawLine(Gfx.sx(ox), Gfx.sy(oy + 11), Gfx.sx(ox + 70), Gfx.sy(oy + 11));
            return;
        }
        var lo = pts[0];
        var hi = pts[0];
        for (var i = 1; i < pts.size(); i++) {
            if (pts[i] < lo) { lo = pts[i]; }
            if (pts[i] > hi) { hi = pts[i]; }
        }
        var span = hi - lo;
        if (span < 6) { lo -= (6 - span) / 2; span = 6.0; }
        var px = 0;
        var py = 0;
        for (var i = 0; i < pts.size(); i++) {
            var x = Gfx.sx(ox + 7.0 * i);
            var y = Gfx.sy(oy + 16 - (pts[i] - lo) / span * 12);
            if (i > 0) { dc.drawLine(px, py, x, y); }
            px = x;
            py = y;
        }
    }

    // ---- active ----

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);
        var L = Graphics.TEXT_JUSTIFY_LEFT;
        var R = Graphics.TEXT_JUSTIFY_RIGHT;

        // Header tile: time, weekday/date, notifications.
        tile(dc, 58, 66, 274, 112, TILE);
        Gfx.text(dc, 80, 118.5, fTime, timeStr(), 0xFFFFFF, L);
        var ds = Data.dateStr();
        Gfx.text(dc, 312, 100.5, fDate, ds.substring(0, ds.find(" ")) as String, accent, R);
        Gfx.text(dc, 312, 120.9, fDate, ds.substring(ds.find(" ") + 1, ds.length()) as String, 0x8A8A8A, R);
        Gfx.text(dc, 312, 152.8, fNotif, Data.fmt(Data.notifications()) + " NOTIF", 0x5A5A5A, R);

        // Steps tile (accent, black text).
        tile(dc, 38, 188, 102, 100, accent);
        Gfx.text(dc, 52, 221.8, fSteps, stepsStr(), 0x000000, L);
        Gfx.text(dc, 52, 251.8, fTag, "STEPS", 0x000000, L);
        bar(dc, 52, 266, 74, 6, stepsPct(), Gfx.dim(accent, 0.82), 0x000000);

        // Heart-rate tile with sparkline and range.
        refreshHr();
        tile(dc, 148, 188, 94, 100, TILE);
        var hr = Data.fmt(Data.heartRate());
        Gfx.text(dc, 162, 219, fHr, hr, 0xFFFFFF, L);
        Gfx.text(dc, 162 + Gfx.width(dc, hr, fHr) + 4, 224.4, fTag, "BPM", HR_RED, L);
        drawSpark(dc);
        var range = mHrLo != null ? mHrLo + "–" + mHrHi : "--";
        Gfx.text(dc, 162, 267.9, fTag, range, GREY, L);

        // Weather tile.
        tile(dc, 250, 188, 102, 100, TILE);
        var temp = Data.temperature();
        var cond = Data.condition();
        Gfx.icon(dc, isSunny(cond) ? :sun : :cloud, 273, 211, 18, temp != null ? 0xFFB347 : 0x5A5A5A);
        Gfx.text(dc, 264, 244.4, fTemp, temp != null ? temp + "°" : "--", 0xFFFFFF, L);
        Gfx.text(dc, 264, 266.0, fTag, highLow(), GREY, L);

        // Battery tile.
        tile(dc, 88, 298, 104, 52, TILE);
        var batt = Data.battery();
        Gfx.text(dc, 104, 320.7, fSmall, batt + "%", 0xFFFFFF, L);
        bar(dc, 104, 334, 72, 4, batt / 100.0, 0x262626, 0xE6E6E6);

        // Body battery tile.
        tile(dc, 200, 298, 104, 52, TILE);
        Gfx.icon(dc, :bolt, 223, 324, 14, BLUE);
        var bb = Data.fmt(Data.bodyBattery());
        Gfx.text(dc, 236, 324.3, fSmall, bb, 0xFFFFFF, L);
        Gfx.text(dc, 236 + Gfx.width(dc, bb, fSmall) + 6, 324.2, fTag, "BODY", BLUE, L);
    }

    // ---- always-on: outlines + grey values only ----

    function drawAod(dc as Dc) as Void {
        var L = Graphics.TEXT_JUSTIFY_LEFT;
        var R = Graphics.TEXT_JUSTIFY_RIGHT;
        outline(dc, 58, 66, 274, 112);
        outline(dc, 38, 188, 102, 100);
        outline(dc, 148, 188, 94, 100);
        outline(dc, 250, 188, 102, 100);

        Gfx.text(dc, 80, 118.5, fTimeAod, timeStr(), 0xA8A8A8, L);
        var ds = Data.dateStr();
        Gfx.text(dc, 312, 100.5, fDateAod, ds.substring(0, ds.find(" ")) as String, 0x6A6A6A, R);
        Gfx.text(dc, 312, 120.9, fDateAod, ds.substring(ds.find(" ") + 1, ds.length()) as String, 0x6A6A6A, R);

        Gfx.text(dc, 52, 219.5, fAod, stepsStr(), 0x8A8A8A, L);
        Gfx.text(dc, 162, 219.5, fAod, Data.fmt(Data.heartRate()), 0x8A8A8A, L);
        Gfx.text(dc, 264, 219.5, fAod, Data.fmt(Data.bodyBattery()), 0x8A8A8A, L);
    }
}
