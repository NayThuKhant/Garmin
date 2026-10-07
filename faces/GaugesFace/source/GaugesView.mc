import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Face G · Six gauges — mockups/Gauges.dc.html (active), mockups/GaugesAOD.dc.html (always-on).
class GaugesView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;
    var fHead as FontResource;
    var fTime as FontResource;
    var fRow as FontResource;
    var fValue as FontResource;
    var fLabel as FontResource;
    var fAodDate as FontResource;
    var fAodTime as FontResource;
    var fAodVal as FontResource;

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fRow = WatchUi.loadResource(Rez.Fonts.Row) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fAodTime = WatchUi.loadResource(Rez.Fonts.AodTime) as FontResource;
        fAodVal = WatchUi.loadResource(Rez.Fonts.AodVal) as FontResource;
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

    function timeStr() as String {
        var t = System.getClockTime();
        return Data.hourStr(t.hour) + ":" + t.min.format("%02d");
    }

    // 7412 -> "7.4k"
    function kStr(v as Number or Null) as String {
        if (v == null) { return "--"; }
        if (v < 1000) { return v.toString(); }
        return (v / 1000.0).format("%.1f") + "k";
    }

    // The six gauges: [value text, fraction, color, label].
    function gauges(accent as Number) as Array<Array> {
        var steps = Data.steps();
        var bb = Data.bodyBattery();
        var st = Data.stress();
        var bat = Data.battery();
        var im = Data.activeMinutesWeek();
        var sl = Ext.sleepScore();
        return [
            [kStr(steps), Ext.frac(steps, Data.stepGoal()), accent, "STEPS"],
            [Data.fmt(bb), Ext.frac(bb, 100), 0x4DA3FF, "BODY"],
            [Data.fmt(st), Ext.frac(st, 100), 0xFF9F1C, "STRESS"],
            [bat + "%", Ext.frac(bat, 100), 0xE6E6E6, "BATT"],
            [im != null ? im + "m" : "--", Ext.frac(im, Data.activeMinutesWeekGoal()), 0xB388FF, "INTENS"],
            [Data.fmt(sl), Ext.frac(sl, 100), 0x9FA8FF, "SLEEP"]
        ];
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);

        // Header (top 44): 14px, letter-spacing 1.5, gap 12.
        Ext.row(dc, 195, 52.4, fHead, 14,
            [Data.dateStr(), Ext.tempStr(), Data.fmt(Data.notifications()) + " NOTIF"],
            [0x9A9A9A, 0xD0D0D0, 0x9A9A9A], [12, 12]);

        // Time 78px condensed, line-height 0.95 (box 62.8..136.9).
        Gfx.text(dc, 195, 99.85, fTime, timeStr(), 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);

        // HR · kcal · sunrise/sunset, 13px, gap 10.
        Ext.row(dc, 195, 144.7, fRow, 13,
            ["HR " + Data.fmt(Data.heartRate()), Data.thousands(Data.calories()) + " kcal",
             "↑" + Data.timeOf(Data.sunrise()), "↓" + Data.timeOf(Data.sunset())],
            [0xFF6B5A, 0xD0D0D0, 0x9A9A9A, 0x9A9A9A], [10, 10, 4]);

        // Two rows of three 60px gauges (r24, stroke 5), gap 14; labels 9px below.
        var g = gauges(accent);
        for (var i = 0; i < 6; i++) {
            var gi = g[i];
            var cx = 195 + (i % 3 - 1) * 74;
            var cy = i < 3 ? 192.5 : 271.3;
            Gfx.arc(dc, cx, cy, 24, 0, 360, 0x262626, 5);
            Ext.roundArc(dc, cx, cy, 24, 0, (gi[1] as Float) * 359.9, gi[2] as Number, 5);
            Gfx.text(dc, cx, cy, fValue, gi[0] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, cy + 37.4, fLabel, gi[3] as String, 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawAod(dc as Dc) as Void {
        Gfx.text(dc, 195, 120.95, fAodDate, Data.dateStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 174.4, fAodTime, timeStr(), 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
        // Three 52px rings (r 20.8, stroke ~1.7, no track), gap 18.
        var g = gauges(0x7A7A7A);
                for (var i = 0; i < 3; i++) {
            var gi = g[i];
            var cx = 195 + (i - 1) * 70;
            Gfx.arc(dc, cx, 251.45, 20.8, 0, (gi[1] as Float) * 359.9, 0x7A7A7A, 1.7);
            Gfx.text(dc, cx, 251.45, fAodVal, gi[0] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
