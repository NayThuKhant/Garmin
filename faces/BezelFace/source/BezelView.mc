import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// Face AD · Bezel — mockups/Bezel.dc.html (active), mockups/BezelAOD.dc.html (always-on).
// A rotating minute bezel: numerals every 5 minutes sit at r170, turned so the
// current minute is under the fixed top marker.
class BezelView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    const CX = 195;
    const CY = 195;
    const HEART = 0xFF6B5A;
    const BLUE = 0x4DA3FF;

    var fTime as FontResource;
    var fTimeAod as FontResource;
    var fNum as FontResource;
    var fNumAod as FontResource;
    var fDate as FontResource;
    var fDateAod as FontResource;
    var fInfo as FontResource;
    var fInfoAod as FontResource;

    // sin/cos of the 60 minute positions (clock angle i*6 degrees).
    var mSin as Array<Float> = [] as Array<Float>;
    var mCos as Array<Float> = [] as Array<Float>;
    // Heart outline, 24-grid units centred on (0,0).
    var mHeart as Array<Float> = [] as Array<Float>;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fNum = WatchUi.loadResource(Rez.Fonts.Num) as FontResource;
        fNumAod = WatchUi.loadResource(Rez.Fonts.NumAod) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fDateAod = WatchUi.loadResource(Rez.Fonts.DateAod) as FontResource;
        fInfo = WatchUi.loadResource(Rez.Fonts.Info) as FontResource;
        fInfoAod = WatchUi.loadResource(Rez.Fonts.InfoAod) as FontResource;
        for (var i = 0; i < 60; i++) {
            var a = Math.toRadians(i * 6);
            mSin.add(Math.sin(a).toFloat());
            mCos.add(Math.cos(a).toFloat());
        }
        for (var t = 0; t < 24; t++) {
            var a = Math.PI * 2 * t / 24;
            var sn = Math.sin(a);
            mHeart.add((10.5 * sn * sn * sn).toFloat());
            mHeart.add((-(8 * Math.cos(a) - 3 * Math.cos(2 * a) - 1.2 * Math.cos(3 * a) - 0.6 * Math.cos(4 * a)) - 1).toFloat());
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

    // ---- helpers ----

    function ptX(i as Number, r as Numeric) as Float {
        return CX + r * mSin[(i % 60 + 60) % 60];
    }
    function ptY(i as Number, r as Numeric) as Float {
        return CY - r * mCos[(i % 60 + 60) % 60];
    }

    // Bezel numerals: minute n (multiple of 5) at clock position n - current minute.
    // `quarters` limits to 00/15/30/45.
    function drawNumerals(dc as Dc, cur as Number, f as FontResource, major as Number, minor as Number,
                          quarters as Boolean) as Void {
        for (var n = 0; n < 60; n += 5) {
            var q = n % 15 == 0;
            if (quarters && !q) { continue; }
            var p = n - cur;
            Gfx.text(dc, ptX(p, 170), ptY(p, 170) + 0.8, f, n.format("%02d"), q ? major : minor,
                     Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawTime(dc as Dc, f as FontResource, color as Number, colon as Number) as Void {
        var t = Data.clock();
        var h = Data.hourStr(t.hour as Number);
        var m = (t.min as Number).format("%02d");
        var wh = Gfx.width(dc, h, f);
        var wc = Gfx.width(dc, ":", f);
        var x = 195 - (wh + wc + Gfx.width(dc, m, f)) / 2;
        var y = 190.8;
        var L = Graphics.TEXT_JUSTIFY_LEFT;
        Gfx.text(dc, x, y, f, h, color, L);
        Gfx.text(dc, x + wh, y, f, ":", colon, L);
        Gfx.text(dc, x + wh + wc, y, f, m, color, L);
    }

    function fillHeart(dc as Dc, cx as Numeric, cy as Numeric, sz as Numeric, color as Number) as Void {
        var f = sz / 24.0;
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < mHeart.size(); i += 2) {
            pts.add([Gfx.sx(cx + mHeart[i] * f), Gfx.sy(cy + mHeart[i + 1] * f)]);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    // ---- active ----

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xFF9F1C);
        var ct = System.getClockTime();
        var cur = ct.min;

        // Bezel ring and inner hairline.
        Gfx.arc(dc, CX, CY, 171, 0, 360, 0x0E0E0E, 38);
        Gfx.arc(dc, CX, CY, 151, 0, 360, 0x262626, 1);

        // Minute ticks r183..188, skipping the 5-minute numeral positions.
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        var pw = Gfx.s(1.5);
        dc.setPenWidth(pw < 1 ? 1 : pw);
        for (var i = 0; i < 60; i++) {
            if ((i + cur) % 5 == 0) { continue; }
            dc.drawLine(Gfx.sx(ptX(i, 183)), Gfx.sy(ptY(i, 183)), Gfx.sx(ptX(i, 188)), Gfx.sy(ptY(i, 188)));
        }

        drawNumerals(dc, cur, fNum, 0xD0D0D0, 0x7A7A7A, false);

        // Fixed top marker.
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[Gfx.sx(195), Gfx.sy(6)], [Gfx.sx(203), Gfx.sy(18)], [Gfx.sx(187), Gfx.sy(18)]]);

        // Seconds dot (awake only).
        var sec = ct.sec;
        dc.fillCircle(Gfx.sx(ptX(sec, 144)), Gfx.sy(ptY(sec, 144)), Gfx.s(3.5));

        Gfx.text(dc, 195, 125.8, fDate, Data.dateStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        drawTime(dc, fTime, 0xFFFFFF, accent);

        // Info row: ♥ HR · BB body battery · battery %, gap 14, centred.
        var f = fInfo;
        var hr = " " + Data.fmt(Data.heartRate());
        var bb = " " + Data.fmt(Data.bodyBattery());
        var batt = Data.battery() + "%";
        var heartW = 10;
        var wHr = Gfx.width(dc, hr, f);
        var wBB = Gfx.width(dc, "BB", f);
        var wBb = Gfx.width(dc, bb, f);
        var total = heartW + wHr + wBB + wBb + Gfx.width(dc, batt, f) + 28;
        var x = 195 - total / 2;
        var y = 252.5;
        var L = Graphics.TEXT_JUSTIFY_LEFT;
        fillHeart(dc, x + heartW / 2.0, y, 10, HEART);
        x += heartW;
        Gfx.text(dc, x, y, f, hr, 0xD0D0D0, L);
        x += wHr + 14;
        Gfx.text(dc, x, y, f, "BB", BLUE, L);
        x += wBB;
        Gfx.text(dc, x, y, f, bb, 0xD0D0D0, L);
        x += wBb + 14;
        Gfx.text(dc, x, y, f, batt, 0xD0D0D0, L);
    }

    // ---- always-on: quarter numerals, outlined marker, grey text ----

    function drawAod(dc as Dc) as Void {
        var cur = System.getClockTime().min;
        Gfx.arc(dc, CX, CY, 151, 0, 360, 0x1A1A1A, 1);
        drawNumerals(dc, cur, fNumAod, 0x5A5A5A, 0x5A5A5A, true);

        Gfx.line(dc, 195, 8, 201, 17, 0x6A6A6A, 1.2);
        Gfx.line(dc, 201, 17, 189, 17, 0x6A6A6A, 1.2);
        Gfx.line(dc, 189, 17, 195, 8, 0x6A6A6A, 1.2);

        Gfx.text(dc, 195, 125.8, fDateAod, Data.dateStr(), 0x5A5A5A, Graphics.TEXT_JUSTIFY_CENTER);
        drawTime(dc, fTimeAod, 0xA8A8A8, 0xA8A8A8);
        Gfx.text(dc, 195, 252.5, fInfoAod,
                 "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery()),
                 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
