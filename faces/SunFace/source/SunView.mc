import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Weather;
import Toybox.WatchUi;

// Face J · Sun arc — mockups/Sun.dc.html (active), mockups/SunAOD.dc.html (always-on).
// The sun travels a half circle (center 195,212, r 166) from sunrise (left, clock -90)
// to sunset (right, clock 90).
class SunView extends WatchUi.WatchFace {

    const CX = 195;
    const CY = 212;
    const R = 166;
    const SUN = 0xFFB000;

    var mSleep as Boolean = false;
    var fWx as FontResource, fDate as FontResource, fTime as FontResource, fSec as FontResource,
        fSun as FontResource, fValue as FontResource, fLabel as FontResource,
        fADate as FontResource, fATime as FontResource, fARow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fWx = WatchUi.loadResource(Rez.Fonts.Wx) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fSec = WatchUi.loadResource(Rez.Fonts.Sec) as FontResource;
        fSun = WatchUi.loadResource(Rez.Fonts.Sun) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fADate = WatchUi.loadResource(Rez.Fonts.ADate) as FontResource;
        fATime = WatchUi.loadResource(Rez.Fonts.ATime) as FontResource;
        fARow = WatchUi.loadResource(Rez.Fonts.ARow) as FontResource;
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

    // Sun position as clock angle (-90 .. 90), clamped to the horizon at night.
    // Null when sunrise/sunset are unknown.
    function sunAngle() as Float or Null {
        var rise = Data.sunrise();
        var set = Data.sunset();
        if (rise == null || set == null) { return null; }
        var r = rise.value();
        var span = set.value() - r;
        if (span <= 0) { return null; }
        var f = (Time.now().value() - r).toFloat() / span;
        if (f < 0) { f = 0.0; }
        if (f > 1) { f = 1.0; }
        return (-90 + 180 * f).toFloat();
    }

    // Temperature in the user's unit from a Celsius value.
    function tempUnit(c as Numeric or Null) as Number or Null {
        if (c == null) { return null; }
        var t = c as Numeric;
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            t = t * 9.0 / 5.0 + 32;
        }
        return Math.round(t).toNumber();
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);
        var ang = sunAngle();
        var a = ang != null ? ang : -90.0;

        // Remaining arc: dotted (dash 2 / gap 7, round caps, width 3).
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        var step = 9.0 / (Math.PI * R / 180.0);   // 9 px of arc in degrees
        var dr = Gfx.s(1.6);
        for (var d = a; d <= 90.01; d += step) {
            dc.fillCircle(Gfx.sx(Gfx.px(CX, R, d)), Gfx.sy(Gfx.py(CY, R, d)), dr < 1 ? 1 : dr);
        }
        // Elapsed arc + sun.
        if (ang != null) {
            Gfx.arc(dc, CX, CY, R, -90, a, SUN, 4);
            var sx = Gfx.px(CX, R, a);
            var sy = Gfx.py(CY, R, a);
            dc.setColor(SUN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(Gfx.sx(sx), Gfx.sy(sy), Gfx.s(9));
            dc.setColor(Gfx.dim(SUN, 0.35), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(Gfx.s(2) < 1 ? 1 : Gfx.s(2));
            dc.drawCircle(Gfx.sx(sx), Gfx.sy(sy), Gfx.s(15));
        }
        Gfx.line(dc, 24, CY, 366, CY, 0x2A2A2A, 1);

        // Weather row: icon, temp, high/low (14px, gap 6), cap center y = 70 + 8.4.
        var wf = fWx;
        var temp = Data.temperature();
        var tStr = temp != null ? temp + "°" : "--°";
        var hi = null;
        var lo = null;
        if (Toybox has :Weather) {
            var c = Weather.getCurrentConditions();
            if (c != null) {
                hi = tempUnit(c.highTemperature);
                lo = tempUnit(c.lowTemperature);
            }
        }
        var hl = "H" + Data.fmt(hi) + " L" + Data.fmt(lo);
        var wT = Gfx.width(dc, tStr, wf);
        var wHL = Gfx.width(dc, hl, wf);
        var x = 195 - (16 + 6 + wT + 6 + wHL) / 2;
        var cond = Data.condition();
        var sunny = cond != null && (cond == Weather.CONDITION_CLEAR || cond == Weather.CONDITION_MOSTLY_CLEAR
            || cond == Weather.CONDITION_FAIR || cond == Weather.CONDITION_PARTLY_CLEAR);
        Gfx.icon(dc, sunny ? :sun : :cloud, x + 8, 78.4, 16, 0xD0D0D0);
        x += 22;
        Gfx.text(dc, x, 78.4, wf, tStr, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
        x += wT + 6;
        Gfx.text(dc, x, 78.4, wf, hl, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);

        Gfx.text(dc, 195, 101.8, fDate, Data.dateStr(), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);

        // Time 90px (line-height 0.95, top 110) + seconds 22px bottom-aligned 10px above.
        var t = Data.clock();
        var tf = fTime;
        var sf = fSec;
        var time = Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
        var sec = (t.sec as Number).format("%02d");
        var wTime = Gfx.width(dc, time, tf);
        var wSec = Gfx.width(dc, sec, sf);
        x = 195 - (wTime + 3 + wSec) / 2;
        Gfx.text(dc, x, 152.75, tf, time, 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + wTime + 3, 175.05, sf, sec, SUN, Graphics.TEXT_JUSTIFY_LEFT);

        // Sunrise / sunset labels under the horizon ends.
        var lf = fSun;
        Gfx.text(dc, 34, 225.2, lf, Data.timeOf(Data.sunrise()), SUN, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, 318, 225.2, lf, Data.timeOf(Data.sunset()), 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);

        // 3x2 data grid, columns centered at 105/195/285.
        var values = [
            Data.fmt(Data.heartRate()),
            Data.thousands(Data.steps()),
            Data.fmt(Data.bodyBattery()),
            Data.fmt(Data.stress()),
            Data.thousands(Data.calories()),
            Data.battery() + "%"
        ];
        var labels = ["BPM", "STEPS", "BODY BATT", "STRESS", "KCAL", "BATT"];
        var colors = [0xFF6B5A, accent, 0x4DA3FF, 0xFF9F1C, 0xFFB36B, 0xD0D0D0];
        var vf = fValue;
        var lbf = fLabel;
        for (var i = 0; i < 6; i++) {
            var cx = 105 + 90 * (i % 3);
            var top = 238 + 40.6 * (i / 3);
            Gfx.text(dc, cx, top + 9.9, vf, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, top + 25.2, lbf, labels[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawAod(dc as Dc) as Void {
        var ang = sunAngle();
        if (ang != null) {
            var c = 0x8A6A1A;
            Gfx.arc(dc, CX, CY, R, -90, ang, c, 2);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(Gfx.sx(Gfx.px(CX, R, ang)), Gfx.sy(Gfx.py(CY, R, ang)), Gfx.s(5));
        }
        var temp = Data.temperature();
        Gfx.text(dc, 195, 101.8, fADate,
            Data.dateStr() + " · " + (temp != null ? temp + "°" : "--°"), 0x7A7A7A, Graphics.TEXT_JUSTIFY_CENTER);

        var t = Data.clock();
        var time = Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
        Gfx.text(dc, 195, 154.75, fATime, time, 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);

        // Bottom row (15px, gap 18), cap center 240 + 9.
        var f = fARow;
        var parts = ["HR " + Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), "BB " + Data.fmt(Data.bodyBattery())];
        var total = 36.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i] as String, f);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 249, f, parts[i] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, f) + 18;
        }
    }
}
