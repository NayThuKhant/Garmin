import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Face D · Info bands — mockups/Bands.dc.html (active), mockups/BandsAOD.dc.html (always-on).
class BandsView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fSec as FontResource;
    var fTimeAod as FontResource;
    var fHead as FontResource;
    var fDate as FontResource;
    var fValue as FontResource;
    var fLabel as FontResource;
    var fBatt as FontResource;
    var fDateAod as FontResource;
    var fRowAod as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fSec = WatchUi.loadResource(Rez.Fonts.Sec) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fBatt = WatchUi.loadResource(Rez.Fonts.Batt) as FontResource;
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
            drawAod(dc);
        } else {
            drawActive(dc);
        }
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }

    function drawAod(dc as Dc) as Void {
        var time = Data.hourStr(System.getClockTime().hour) + ":" + Ex.minStr();
        // Centered column, gap 6: date 14px, time 100px (lh .95), divider, 3-column row 16px.
        Gfx.text(dc, 195, 126.4, fDateAod, Ex.longDateStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 188.3, fTimeAod, time, 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.rect(dc, 95, 245.8, 200, 1, 0x1F1F1F);
        var f = fRowAod;
        var vals = ["HR " + Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), "BB " + Data.fmt(Data.bodyBattery())];
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, 115 + 80 * i, 262.4, f, vals[i], 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);

        drawHeader(dc, 52.4);
        Gfx.text(dc, 195, 77.2, fDate, Ex.longDateStr(), accent, Graphics.TEXT_JUSTIFY_CENTER);

        // Time 100px + seconds 26px (grey), bottom-aligned with margin-bottom 10.
        var time = Data.hourStr(System.getClockTime().hour) + ":" + Ex.minStr();
        var tf = fTime;
        var sf = fSec;
        var sec = Ex.secStr();
        var wt = Gfx.width(dc, time, tf);
        var ws = Gfx.width(dc, sec, sf);
        var x = 195 - (wt + 4 + ws) / 2;
        Gfx.text(dc, x, 133.1, tf, time, 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + wt + 4, 158.3, sf, sec, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);

        Gfx.rect(dc, 45, 188.6, 300, 1, 0x2A2A2A);

        // 3x2 grid, 300 wide from y 199.6, cells 36 high, row gap 10.
        var o2 = Data.spo2();
        var icons = [:heart, :steps, :flame, :bolt, :pulse, :drop];
        var colors = [0xFF6B5A, accent, 0xFFB36B, 0x4DA3FF, 0xFF9F1C, 0x4DD0E1];
        var vals = [
            Data.fmt(Data.heartRate()),
            Data.thousands(Data.steps()),
            Data.thousands(Data.calories()),
            Data.fmt(Data.bodyBattery()),
            Data.fmt(Data.stress()),
            o2 != null ? o2 + "%" : "--"
        ];
        var labels = ["BPM", "STEPS", "KCAL", "BODY BATT", "STRESS", "SPO2"];
        for (var i = 0; i < 6; i++) {
            var cx = 95 + (i % 3) * 100;
            var top = 199.6 + (i / 3) * 46;
            Ex.iconRow(dc, cx, top + 12, fValue, [icons[i]], [15], [colors[i] as Number],
                [vals[i] as String], [0xFFFFFF], 4, 0);
            Gfx.text(dc, cx, top + 31, fLabel, labels[i] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        }
        Gfx.rect(dc, 145, 199.6, 1, 36, 0x2A2A2A);
        Gfx.rect(dc, 244, 199.6, 1, 36, 0x2A2A2A);
        Gfx.rect(dc, 145, 245.6, 1, 36, 0x2A2A2A);
        Gfx.rect(dc, 244, 245.6, 1, 36, 0x2A2A2A);

        // Battery bar 120x6 + "82% · 9d", centered row at y 303.4.
        var batt = Data.battery();
        var days = Ex.batteryDays();
        var bs = batt + "%" + (days != null ? " · " + days + "d" : "");
        var bfont = fBatt;
        var total = 128 + Gfx.width(dc, bs, bfont);
        var bx = 195 - total / 2;
        dc.setColor(0x262626, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(Gfx.sx(bx), Gfx.sy(300.4), Gfx.s(120), Gfx.s(6), Gfx.s(3));
        var fw = 120 * Ex.frac(batt, 100);
        if (fw >= 1) {
            dc.setColor(0xE6E6E6, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(Gfx.sx(bx), Gfx.sy(300.4), Gfx.s(fw), Gfx.s(6), Gfx.s(fw < 6 ? fw / 2 : 3));
        }
        Gfx.text(dc, bx + 128, 303.4, bfont, bs, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Weather · sunrise/sunset · notifications, 14px, gap 14.
    function drawHeader(dc as Dc, y as Numeric) as Void {
        var f = fHead;
        var temp = Ex.tempStr();
        var rise = Data.timeOf(Data.sunrise());
        var set = Data.timeOf(Data.sunset());
        var notif = Data.fmt(Data.notifications());
        var wTemp = Gfx.width(dc, temp, f);
        var wRise = Gfx.width(dc, rise, f);
        var wSet = Gfx.width(dc, set, f);
        var wSpace = Gfx.width(dc, " ", f);
        var wNotif = Gfx.width(dc, notif, f);
        var arrow = 8;
        var wSun = arrow + 1 + wRise + wSpace + arrow + 1 + wSet;
        var total = (16 + 4 + wTemp) + 14 + wSun + 14 + (14 + 4 + wNotif);
        var x = 195 - total / 2;

        Gfx.icon(dc, Ex.weatherIcon(), x + 8, y, 16, 0xD0D0D0);
        Gfx.text(dc, x + 20, y, f, temp, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
        x += 20 + wTemp + 14;

        drawArrow(dc, x + arrow / 2.0, y, true, 0x9A9A9A);
        Gfx.text(dc, x + arrow + 1, y, f, rise, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        x += arrow + 1 + wRise + wSpace;
        drawArrow(dc, x + arrow / 2.0, y, false, 0x9A9A9A);
        Gfx.text(dc, x + arrow + 1, y, f, set, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        x += arrow + 1 + wSet + 14;

        Gfx.icon(dc, :bell, x + 7, y, 14, 0xD0D0D0);
        Gfx.text(dc, x + 18, y, f, notif, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawArrow(dc as Dc, cx as Float, cy as Numeric, up as Boolean, color as Number) as Void {
        var tip = up ? cy - 5 : cy + 5;
        var tail = up ? cy + 5 : cy - 5;
        var wing = up ? tip + 3.5 : tip - 3.5;
        Gfx.line(dc, cx, tail, cx, tip, color, 1.4);
        Gfx.line(dc, cx - 3, wing, cx, tip, color, 1.4);
        Gfx.line(dc, cx + 3, wing, cx, tip, color, 1.4);
    }
}
