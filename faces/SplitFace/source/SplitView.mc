import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face I · Split — mockups/Split.dc.html (active), mockups/SplitAOD.dc.html (always-on).
class SplitView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (faces/SplitFace/fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fTimeAod as FontResource;
    var fHead as FontResource;
    var fValue as FontResource;
    var fLabel as FontResource;
    var fSun as FontResource;
    var fAodDate as FontResource;
    var fAodInfo as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fSun = WatchUi.loadResource(Rez.Fonts.Sun) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fAodInfo = WatchUi.loadResource(Rez.Fonts.AodInfo) as FontResource;
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

    // Stacked hour over minute, right-aligned at x=180.
    function drawTime(dc as Dc, f as FontResource, hourColor as Number, minColor as Number) as Void {
        var t = Data.clock();
        // line-height 0.85 * 122 = 103.7, box top 92
        Gfx.text(dc, 180, 92 + 51.85, f, Data.hourStr(t.hour as Number), hourColor, Graphics.TEXT_JUSTIFY_RIGHT);
        Gfx.text(dc, 180, 92 + 155.55, f, (t.min as Number).format("%02d"), minColor, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);

        // Header: date · temperature · notifications, 13px, letter-spacing 1.5, gap 10.
        var small = fHead;
        var temp = Data.temperature();
        var notif = Data.notifications();
        var parts = [Data.dateStr(), temp != null ? temp + "°" : "--°", Data.fmt(notif) + " NOTIF"];
        var colors = [0x9A9A9A, 0xD0D0D0, 0x9A9A9A];
        var total = 20.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i] as String, small);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 57.8, small, parts[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, small) + 10;
        }

        drawTime(dc, fTime, 0xFFFFFF, accent);

        Gfx.rect(dc, 194, 104, 1, 184, 0x2A2A2A);

        // Data column: 7 rows of 25px from y=107.
        var hr = Data.heartRate();
        var bb = Data.bodyBattery();
        var st = Data.stress();
        var o2 = Data.spo2();
        var icons = [:heart, :steps, :flame, :bolt, :pulse, :drop, :battery];
        var iconColors = [0xFF6B5A, accent, 0xFFB36B, 0x4DA3FF, 0xFF9F1C, 0x4DD0E1, 0xE6E6E6];
        var values = [
            Data.fmt(hr),
            Data.thousands(Data.steps()),
            Data.thousands(Data.calories()),
            Data.fmt(bb),
            Data.fmt(st),
            o2 != null ? o2 + "%" : "--",
            Data.battery() + "%"
        ];
        var labels = ["BPM", "STEPS", "KCAL", "BODY", "STRESS", "SPO2", "BATT"];
        var vf = fValue;
        var lf = fLabel;
        for (var i = 0; i < 7; i++) {
            var cy = 119.5 + 25 * i;
            Gfx.icon(dc, icons[i] as Symbol, 215.5, cy, 15, iconColors[i] as Number);
            Gfx.text(dc, 231, cy, vf, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
            Gfx.text(dc, 289, cy, lf, labels[i] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Footer: sunrise / sunset.
        var sf = fSun;
        var rise = Data.timeOf(Data.sunrise());
        var set = Data.timeOf(Data.sunset());
        var wRise = Gfx.width(dc, rise, sf);
        var wSet = Gfx.width(dc, set, sf);
        var arrow = 9;
        var gap = 3;
        var tw = arrow + gap + wRise + 10 + arrow + gap + wSet;
        x = 195 - tw / 2;
        drawArrow(dc, x + arrow / 2.0, 322, true, 0x9A9A9A);
        Gfx.text(dc, x + arrow + gap, 322, sf, rise, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        x += arrow + gap + wRise + 10;
        drawArrow(dc, x + arrow / 2.0, 322, false, 0x9A9A9A);
        Gfx.text(dc, x + arrow + gap, 322, sf, set, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawArrow(dc as Dc, cx as Float, cy as Numeric, up as Boolean, color as Number) as Void {
        var tip = up ? cy - 5 : cy + 5;
        var tail = up ? cy + 5 : cy - 5;
        var wing = up ? tip + 3.5 : tip - 3.5;
        Gfx.line(dc, cx, tail, cx, tip, color, 1.5);
        Gfx.line(dc, cx - 3, wing, cx, tip, color, 1.5);
        Gfx.line(dc, cx + 3, wing, cx, tip, color, 1.5);
    }

    function drawAod(dc as Dc) as Void {
        Gfx.text(dc, 195, 67.8, fAodDate, Data.dateStr(), 0x7A7A7A, Graphics.TEXT_JUSTIFY_CENTER);
        drawTime(dc, fTimeAod, 0xA8A8A8, 0xA8A8A8);
        Gfx.rect(dc, 194, 140, 1, 110, 0x1F1F1F);
        var f = fAodInfo;
        Gfx.text(dc, 210, 159.6, f, "HR " + Data.fmt(Data.heartRate()), 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, 210, 188.8, f, "BB " + Data.fmt(Data.bodyBattery()), 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, 210, 218, f, Data.battery() + "%", 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
