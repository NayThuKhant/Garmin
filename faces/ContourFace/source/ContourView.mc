import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;
import Toybox.WatchUi;

// Face N · Contour — mockups/Contour.dc.html (active), mockups/ContourAOD.dc.html (always-on).
class ContourView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;
    var mCos as Array<Float> = [] as Array<Float>;
    var mSin as Array<Float> = [] as Array<Float>;

    const LINE = 0x1F3D39;
    const LABEL = 0x6F8F8A;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py).
    var fDate as FontResource;
    var fTime as FontResource;
    var fTimeAod as FontResource;
    var fGrid as FontResource;
    var fFoot as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fGrid = WatchUi.loadResource(Rez.Fonts.Grid) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
        for (var j = 0; j < 72; j++) {
            var a = Math.toRadians(j * 5);
            mCos.add(Math.cos(a).toFloat());
            mSin.add(Math.sin(a).toFloat());
        }
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

    // One contour ring (closed polyline around the peak at 268,128).
    function drawRing(dc as Dc, i as Number, color as Number, w as Numeric) as Void {
        var lo = ContourData.RMIN[i];
        var span = (ContourData.RMAX[i] - lo) / 255.0;
        var b = ContourData.B;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pw = Gfx.s(w);
        dc.setPenWidth(pw < 1 ? 1 : pw);
        var px0 = 0.0;
        var py0 = 0.0;
        var in0 = false;
        for (var j = 0; j <= 72; j++) {
            var jj = j % 72;
            var r = lo + b[i * 72 + jj] * span;
            var x = 268 + r * mCos[jj];
            var y = 128 + r * mSin[jj];
            var ex = x - 195;
            var ey = y - 195;
            var inside = ex * ex + ey * ey < 215 * 215;
            if (j > 0 && (inside || in0)) {
                dc.drawLine(Gfx.sx(px0), Gfx.sy(py0), Gfx.sx(x), Gfx.sy(y));
            }
            px0 = x;
            py0 = y;
            in0 = inside;
        }
    }

    // "MON 05.10"
    function dateStr() as String {
        var now = Time.now();
        var m = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var s = Gregorian.info(now, Time.FORMAT_SHORT);
        return (m.day_of_week as String).toUpper() + " " + (s.day as Number).format("%02d") + "." + (s.month as Number).format("%02d");
    }

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0x5EEAD4);

        for (var i = 0; i < ContourData.N; i++) {
            if (i == ContourData.ACCENT_RING) {
                drawRing(dc, i, Gfx.dim(accent, 0.85), 1.6);
            } else {
                drawRing(dc, i, LINE, 1.1);
            }
        }
        // Summit marker.
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(268), Gfx.sy(128), Gfx.s(4));
        Gfx.arc(dc, 268, 128, 10, 0, 360, Gfx.dim(accent, 0.5), 1);

        // Date + temperature, 12px, letter-spacing 2, box top 112.
        var temp = Data.temperature();
        var unit = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? "F" : "C";
        var head = dateStr() + " · " + (temp != null ? temp + "°" + unit : "--°" + unit);
        Gfx.text(dc, 62, 119.2, fDate, head, LABEL, Graphics.TEXT_JUSTIFY_LEFT);

        // Time, 92px, line-height 1 -> box 126.4..218.4.
        Gfx.text(dc, 62, 172.4, fTime, timeStr(), 0xF2F2F2, Graphics.TEXT_JUSTIFY_LEFT);

        // Data grid: border-top at 222, padding 10, two columns of 116 px, rows 14.4 + gap 4.
        Gfx.rect(dc, 70, 222, 250, 1, LINE);
        var o2 = Data.spo2();
        var labels = ["hr", "bb", "steps", "stress", "kcal", "spo2", "rise", "set"];
        var values = [
            Data.fmt(Data.heartRate()), Data.fmt(Data.bodyBattery()),
            Data.fmt(Data.steps()), Data.fmt(Data.stress()),
            Data.fmt(Data.calories()), o2 != null ? o2 + "%" : "--",
            Data.timeOf(Data.sunrise()), Data.timeOf(Data.sunset())
        ];
        var colors = [0xFF6B5A, 0x4DA3FF, accent, 0xFF9F1C, 0xE6E6E6, 0xE6E6E6, 0xE6E6E6, 0xE6E6E6];
        var f = fGrid;
        for (var i = 0; i < 8; i++) {
            var x0 = (i % 2 == 0) ? 70 : 204;
            var cy = 239.2 + 18.4 * (i / 2);
            Gfx.text(dc, x0, cy, f, labels[i] as String, LABEL, Graphics.TEXT_JUSTIFY_LEFT);
            Gfx.text(dc, x0 + 116, cy, f, values[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Footer: "bat 82%   notif 3", 11px, letter-spacing 1, gap 14, top 322.
        var ff = fFoot;
        var a = "bat " + Data.battery() + "%";
        var b = "notif " + Data.fmt(Data.notifications());
        var wa = Gfx.width(dc, a, ff);
        var wb = Gfx.width(dc, b, ff);
        var x = 195 - (wa + 14 + wb) / 2;
        Gfx.text(dc, x, 328.6, ff, a, LABEL, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + wa + 14, 328.6, ff, b, LABEL, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawAod(dc as Dc) as Void {
        drawRing(dc, ContourData.ACCENT_RING, 0x2A4A46, 1.2);
        dc.setColor(0x2A4A46, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(268), Gfx.sy(128), Gfx.s(3));

        Gfx.text(dc, 62, 119.2, fDate, dateStr(), 0x4F6A66, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, 62, 172.4, fTimeAod, timeStr(), 0xA8A8A8, Graphics.TEXT_JUSTIFY_LEFT);
        var s = "hr " + Data.fmt(Data.heartRate()) + " · bb " + Data.fmt(Data.bodyBattery()) + " · bat " + Data.battery();
        Gfx.text(dc, 70, 239.2, fGrid, s, 0x4F6A66, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
