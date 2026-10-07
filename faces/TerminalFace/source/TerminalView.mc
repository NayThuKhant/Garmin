import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face H · Terminal — mockups/Terminal.dc.html (active), mockups/TerminalAOD.dc.html (always-on).
// Fonts: JetBrains Mono bitmap fonts generated from fonts.json (tools/mkfont.py).
class TerminalView extends WatchUi.WatchFace {

    const LEFT = 77;   // column left (width 236)
    const RIGHT = 313; // column right
    const GREY = 0x8A8A8A;
    const FG = 0xE6E6E6;

    var mSleep as Boolean = false;
    var fSmall as FontResource;
    var fGrid as FontResource;
    var fPrompt as FontResource;
    var fSec as FontResource;
    var fTime as FontResource;
    var fAodTime as FontResource;

    function initialize() {
        WatchFace.initialize();
        fSmall = WatchUi.loadResource(Rez.Fonts.Small) as FontResource;
        fGrid = WatchUi.loadResource(Rez.Fonts.Grid) as FontResource;
        fPrompt = WatchUi.loadResource(Rez.Fonts.Prompt) as FontResource;
        fSec = WatchUi.loadResource(Rez.Fonts.Sec) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fAodTime = WatchUi.loadResource(Rez.Fonts.AodTime) as FontResource;
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

    // Consecutive colored segments starting at x (right-aligned at x when `right`); returns width.
    function seq(dc as Dc, x as Numeric, y as Numeric, f as FontResource, parts as Array<String>,
                 colors as Array<Number>, right as Boolean) as Float {
        var total = 0.0;
        for (var i = 0; i < parts.size(); i++) {
            total += Gfx.width(dc, parts[i], f);
        }
        var cx = right ? x - total : x;
        for (var i = 0; i < parts.size(); i++) {
            Gfx.text(dc, cx, y, f, parts[i], colors[i], Graphics.TEXT_JUSTIFY_LEFT);
            cx += Gfx.width(dc, parts[i], f);
        }
        return total;
    }

    // "mon 2026-10-05"
    function isoDate() as String {
        var now = Time.now();
        var m = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var s = Gregorian.info(now, Time.FORMAT_SHORT);
        return (m.day_of_week as String).toLower() + " " + s.year + "-" +
            (s.month as Number).format("%02d") + "-" + s.day.format("%02d");
    }

    // Zero-padded "05:58".
    function hm(m as Time.Moment or Null) as String {
        var s = Data.timeOf(m);
        return s.length() == 4 ? "0" + s : s;
    }

    function timeStr() as String {
        var t = System.getClockTime();
        var h = Data.hourStr(t.hour);
        return (h.length() == 1 ? "0" + h : h) + ":" + t.min.format("%02d");
    }

    function distStr() as String {
        var d = Data.distance();
        if (d == null) { return "--"; }
        return d.format("%.1f") + (Data.distanceUnit().equals("MI") ? "mi" : "k");
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);
        var L = LEFT;
        var J = Graphics.TEXT_JUSTIFY_LEFT;

        // Date line (13px).
        var temp = Data.temperature();
        var unit = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? "F" : "C";
        Gfx.text(dc, L, 90.95, fSmall, isoDate() + " · " + (temp != null ? temp + "°" + unit : "--"), GREY, J);

        // Prompt, time, seconds (baseline-aligned, gap 6).
        var t = System.getClockTime();
        Gfx.text(dc, L, 145.8, fPrompt, ">", accent, J);
        var x = L + Gfx.width(dc, ">", fPrompt) + 6;
        var ts = timeStr();
        Gfx.text(dc, x, 131.9, fTime, ts, 0xFFFFFF, J);
        x += Gfx.width(dc, ts, fTime) + 6;
        Gfx.text(dc, x, 145.8, fSec, t.sec.format("%02d"), GREY, J);

        // 2-column grid, 5 rows (14px, row-gap 3), columns 112 wide, gap 12.
        var o2 = Data.spo2();
        var im = Data.activeMinutesWeek();
        var rows = [
            ["hr", Data.fmt(Data.heartRate()), 0xFF6B5A, "bb", Data.fmt(Data.bodyBattery()), 0x4DA3FF],
            ["steps", Data.fmt(Data.steps()), accent, "str", Data.fmt(Data.stress()), 0xFF9F1C],
            ["dist", distStr(), FG, "spo2", o2 != null ? o2 + "%" : "--", 0x4DD0E1],
            ["kcal", Data.fmt(Data.calories()), FG, "resp", Data.fmt(Ext.respiration()), FG],
            ["int", im != null ? im + "m" : "--", 0xB388FF, "sleep", Data.fmt(Ext.sleepScore()), 0x9FA8FF]
        ];
        var R = Graphics.TEXT_JUSTIFY_RIGHT;
        for (var i = 0; i < 5; i++) {
            var r = rows[i];
            var y = 178.05 + i * 19.8;
            Gfx.text(dc, L, y, fGrid, r[0] as String, GREY, J);
            Gfx.text(dc, L + 112, y, fGrid, r[1] as String, r[2] as Number, R);
            Gfx.text(dc, L + 124, y, fGrid, r[3] as String, GREY, J);
            Gfx.text(dc, RIGHT, y, fGrid, r[4] as String, r[5] as Number, R);
        }

        // sun 05:58 → 17:52
        Gfx.text(dc, L, 280.45, fSmall, "sun " + hm(Data.sunrise()) + " → " + hm(Data.sunset()), GREY, J);

        // notif / bat: same columns as the grid, values right-aligned.
        Gfx.text(dc, L, 299.05, fGrid, "notif", GREY, J);
        Gfx.text(dc, L + 112, 299.05, fGrid, Data.fmt(Data.notifications()), FG, R);
        Gfx.text(dc, L + 124, 299.05, fGrid, "bat", GREY, J);
        Gfx.text(dc, RIGHT, 299.05, fGrid, Data.battery() + "%", FG, R);
    }

    function drawAod(dc as Dc) as Void {
        var dim = 0x7A7A7A;
        var J = Graphics.TEXT_JUSTIFY_LEFT;
        Gfx.text(dc, LEFT, 151.45, fSmall, isoDate(), dim, J);
        Gfx.text(dc, LEFT, 207.3, fSec, ">", dim, J);
        var x = LEFT + Gfx.width(dc, ">", fSec) + 6;
        var ts = timeStr();
        Gfx.text(dc, x, 193.4, fAodTime, ts, 0xA8A8A8, J);
        x += Gfx.width(dc, ts, fAodTime) + 6;
        Gfx.text(dc, x, 207.3, fSec, "_", dim, J);
        Gfx.text(dc, LEFT, 236.55, fGrid,
            "hr " + Data.fmt(Data.heartRate()) + " · bb " + Data.fmt(Data.bodyBattery()) + " · bat " + Data.battery(),
            dim, J);
    }
}
