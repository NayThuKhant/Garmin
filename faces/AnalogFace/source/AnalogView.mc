import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face E · Analog chrono — mockups/Analog.dc.html (active), mockups/AnalogAOD.dc.html (always-on).
class AnalogView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;
    var fHead as FontResource;
    var fDay as FontResource;
    var fVal20 as FontResource;
    var fVal18 as FontResource;
    var fLabel as FontResource;
    var fAodDate as FontResource;
    var fAodRow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fDay = WatchUi.loadResource(Rez.Fonts.Day) as FontResource;
        fVal20 = WatchUi.loadResource(Rez.Fonts.Val20) as FontResource;
        fVal18 = WatchUi.loadResource(Rez.Fonts.Val18) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fAodRow = WatchUi.loadResource(Rez.Fonts.AodRow) as FontResource;
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

    function dayName() as String {
        var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return (d.day_of_week as String).toUpper();
    }

    // Hand from radius r0 (negative = tail) to r1 at clock angle deg.
    function hand(dc as Dc, deg as Float, r0 as Numeric, r1 as Numeric, color as Number, w as Numeric) as Void {
        Ext.roundLine(dc, Gfx.px(195, r0, deg), Gfx.py(195, r0, deg), Gfx.px(195, r1, deg), Gfx.py(195, r1, deg), color, w);
    }

    // Subdial: track ring, value arc, value + label.
    function subdial(dc as Dc, cx as Numeric, cy as Numeric, f as Float, color as Number,
                     value as String, vsize as Numeric, vf as FontResource, label as String) as Void {
        Gfx.arc(dc, cx, cy, 40, 0, 360, 0x262626, 5);
        Ext.roundArc(dc, cx, cy, 40, 0, f * 359.9, color, 5);
        // column: value (line-height 1) + label (9px, line-height 1.2), centered on cy
        var h = vsize + 10.8;
        var top = cy - h / 2;
        Gfx.text(dc, cx, top + vsize / 2.0, vf, value, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, cx, top + vsize + 5.4, fLabel, label, color, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);
        var t = System.getClockTime();

        // Ticks: 60, minor r186->178, major r186->166.
        for (var i = 0; i < 60; i++) {
            var a = i * 6;
            if (i % 5 == 0) {
                Ext.roundLine(dc, Gfx.px(195, 186, a), Gfx.py(195, 186, a), Gfx.px(195, 166, a), Gfx.py(195, 166, a), 0xD0D0D0, 4);
            } else {
                Gfx.line(dc, Gfx.px(195, 186, a), Gfx.py(195, 186, a), Gfx.px(195, 178, a), Gfx.py(195, 178, a), 0x4A4A4A, 2);
            }
        }

        // Header column (top 52, gap 4).
        Ext.row(dc, 195, 59.8, fHead, 13,
            [Ext.tempStr(), "↑" + Data.timeOf(Data.sunrise()), "↓" + Data.timeOf(Data.sunset())],
            [0x9A9A9A, 0x9A9A9A, 0x9A9A9A], [10, 10]);

        // Day + accent date badge (14px, letter-spacing 2).
        var day = dayName();
        var dnum = Data.clock().day.format("%02d");
        var wDay = Gfx.width(dc, day, fDay);
        var wNum = Gfx.width(dc, dnum, fDay);
        var wBadge = wNum + 12;
        var x = 195 - (wDay + 6 + wBadge) / 2;
        Gfx.text(dc, x, 81, fDay, day, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        var bx = x + wDay + 6;
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(Gfx.sx(bx), Gfx.sy(81 - 9.4), Gfx.s(wBadge), Gfx.s(18.8), Gfx.s(4));
        Gfx.text(dc, bx + 6, 81, fDay, dnum, 0x000000, Graphics.TEXT_JUSTIFY_LEFT);

        // kcal | notif | battery
        Ext.row(dc, 195, 104.2, fHead, 13,
            [Data.thousands(Data.calories()) + " kcal", "|", Data.fmt(Data.notifications()) + " notif", "|", Data.battery() + "%"],
            [0xD0D0D0, 0x4A4A4A, 0xD0D0D0, 0x4A4A4A, 0xD0D0D0], [10, 10, 10, 10]);

        // Subdials.
        var hr = Data.heartRate();
        var bb = Data.bodyBattery();
        var steps = Data.steps();
        subdial(dc, 115, 200, Ext.frac(hr, 190), 0xFF6B5A, Data.fmt(hr), 20, fVal20, "BPM");
        subdial(dc, 275, 200, Ext.frac(bb, 100), 0x4DA3FF, Data.fmt(bb), 20, fVal20, "BODY");
        subdial(dc, 195, 290, Ext.frac(steps, Data.stepGoal()), accent, Data.thousands(steps), 18, fVal18, "STEPS");

        // Hands.
        var hDeg = ((t.hour % 12) * 30 + t.min * 0.5).toFloat();
        var mDeg = (t.min * 6 + t.sec * 0.1).toFloat();
        var sDeg = (t.sec * 6).toFloat();
        hand(dc, hDeg, 0, 92, 0xFFFFFF, 9);
        hand(dc, mDeg, 0, 148, 0xFFFFFF, 5);
        hand(dc, sDeg, -26, 162, accent, 2);
        Ext.dot(dc, 195, 195, 8, 0xFFFFFF);
        Ext.dot(dc, 195, 195, 3, accent);
    }

    function drawAod(dc as Dc) as Void {
        var t = System.getClockTime();
        for (var i = 0; i < 12; i++) {
            var a = i * 30;
            Ext.roundLine(dc, Gfx.px(195, 186, a), Gfx.py(195, 186, a), Gfx.px(195, 170, a), Gfx.py(195, 170, a), 0x6A6A6A, 3);
        }
        Gfx.text(dc, 195, 86.4, fAodDate, dayName() + " " + Data.clock().day.format("%02d"), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        Ext.row(dc, 195, 292.4, fAodRow, 14,
            ["HR " + Data.fmt(Data.heartRate()), "BB " + Data.fmt(Data.bodyBattery())],
            [0x8A8A8A, 0x8A8A8A], [16]);

        var hDeg = ((t.hour % 12) * 30 + t.min * 0.5).toFloat();
        var mDeg = (t.min * 6).toFloat();
        hand(dc, hDeg, 0, 92, 0xB0B0B0, 6);
        hand(dc, mDeg, 0, 148, 0xB0B0B0, 3);
        Ext.dot(dc, 195, 195, 5, 0xB0B0B0);
    }
}
