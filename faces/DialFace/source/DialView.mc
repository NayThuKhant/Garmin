import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Face C · Quad dial — mockups/Dial.dc.html (active), mockups/DialAOD.dc.html (always-on).
// Four quadrant arcs: steps (TR), body battery (BR), stress (BL), battery (TL).
class DialView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fSec as FontResource;
    var fTimeAod as FontResource;
    var fTemp as FontResource;
    var fDate as FontResource;
    var fCorner as FontResource;
    var fRow as FontResource;
    var fSun as FontResource;
    var fDateAod as FontResource;
    var fRowAod as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fSec = WatchUi.loadResource(Rez.Fonts.Sec) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fTemp = WatchUi.loadResource(Rez.Fonts.Temp) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fCorner = WatchUi.loadResource(Rez.Fonts.Corner) as FontResource;
        fRow = WatchUi.loadResource(Rez.Fonts.Row) as FontResource;
        fSun = WatchUi.loadResource(Rez.Fonts.Sun) as FontResource;
        fDateAod = WatchUi.loadResource(Rez.Fonts.DateAod) as FontResource;
        fRowAod = WatchUi.loadResource(Rez.Fonts.RowAod) as FontResource;
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
        }
        var accent = Gfx.accent(0xC6F432);
        var steps = Data.steps();
        var bb = Data.bodyBattery();
        var stress = Data.stress();
        var batt = Data.battery();
        var fracs = [Ex.frac(steps, Data.stepGoal()), Ex.frac(bb, 100), Ex.frac(stress, 100), Ex.frac(batt, 100)];
        var colors = [accent, 0x4DA3FF, 0xFF9F1C, 0xE6E6E6];
        var time = Data.hourStr(System.getClockTime().hour) + ":" + Ex.minStr();
        var hr = Data.heartRate();

        if (mSleep) {
            for (var i = 0; i < 4; i++) {
                var a0 = 10 + 90 * i;
                Ex.gauge(dc, 195, 195, 180, a0, a0 + 70, fracs[i] as Float, null, Gfx.dim(colors[i] as Number, 0.4), 2);
            }
            // Centered column, gap 6: date 15px, time 96px, row 16px.
            Gfx.text(dc, 195, 131.4, fDateAod, Data.dateStr() + " · " + Ex.tempStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, 195, 194.4, fTimeAod, time, 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
            Ex.iconRow(dc, 195, 258, fRowAod, [null, null, null], [0, 0, 0], [0, 0, 0],
                ["HR " + Data.fmt(hr), "BB " + Data.fmt(bb), batt + "%"],
                [0x8A8A8A, 0x8A8A8A, 0x8A8A8A], 0, 18);
            Gfx.aodMask(dc);
            return;
        }

        for (var i = 0; i < 4; i++) {
            var a0 = 10 + 90 * i;
            Ex.gauge(dc, 195, 195, 180, a0, a0 + 70, fracs[i] as Float, 0x262626, colors[i] as Number, 7);
        }

        // Corner readouts: icon over value, 60 wide boxes at x 59/271, y 72/276.
        var cxs = [301, 301, 89, 89];
        var iys = [79.5, 283.5, 283.5, 80];
        var tys = [97, 301, 301, 98];
        var icons = [:steps, :bolt, :pulse, :battery];
        var sizes = [15, 15, 15, 16];
        var vals = [Data.thousands(steps), Data.fmt(bb), Data.fmt(stress), batt + "%"];
        for (var i = 0; i < 4; i++) {
            Gfx.icon(dc, icons[i] as Symbol, cxs[i] as Number, iys[i] as Numeric, sizes[i] as Number, colors[i] as Number);
            Gfx.text(dc, cxs[i] as Number, tys[i] as Numeric, fCorner, vals[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Center column from padding-top 40.
        Ex.iconRow(dc, 195, 49.6, fTemp, [Ex.weatherIcon()], [18], [0xD0D0D0],
            [Ex.tempStr()], [0xD0D0D0], 6, 0);
        Gfx.text(dc, 195, 78.2, fDate, Data.dateStr(), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);

        // Time 96px + seconds 26px (accent), top-aligned, margin-left 4.
        var tf = fTime;
        var sf = fSec;
        var sec = Ex.secStr();
        var wt = Gfx.width(dc, time, tf);
        var ws = Gfx.width(dc, sec, sf);
        var x = 195 - (wt + 4 + ws) / 2;
        Gfx.text(dc, x, 137.2, tf, time, 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + wt + 4, 116.2, sf, sec, accent, Graphics.TEXT_JUSTIFY_LEFT);

        Ex.iconRow(dc, 195, 200, fRow,
            [:heart, :flame, :bell], [16, 16, 16], [0xFF6B5A, 0xFFB36B, 0xD0D0D0],
            [Data.fmt(hr), Data.thousands(Data.calories()), Data.fmt(Data.notifications())],
            [0xFFFFFF, 0xFFFFFF, 0xFFFFFF], 5, 16);

        Ex.iconRow(dc, 195, 236.6, fSun, [null, null], [0, 0], [0, 0],
            ["RISE " + Data.timeOf(Data.sunrise()), "SET " + Data.timeOf(Data.sunset())],
            [0x9A9A9A, 0x9A9A9A], 0, 14);
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }
}
