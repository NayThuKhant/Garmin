import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face L · Bold stack — mockups/Bold.dc.html (active), mockups/BoldAOD.dc.html (always-on).
// Huge stacked hour/minute in the center, three stats on each side.
class BoldView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    var fDate as FontResource, fTime as FontResource, fValue as FontResource, fLabel as FontResource, fFoot as FontResource, fADate as FontResource, fATime as FontResource, fARow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
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

    // 158px numerals, line-height 0.8 (126.4) from top 62: cap centers 125.2 / 251.6.
    function timeStrings() as Array<String> {
        var t = Data.clock();
        return [Data.hourStr(t.hour as Number), (t.min as Number).format("%02d")];
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);

        Gfx.text(dc, 195, 47.8, fDate, Data.dateStr(), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);

        var tf = fTime;
        var hm = timeStrings();
        Gfx.text(dc, 195, 125.2, tf, hm[0], 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 251.6, tf, hm[1], accent, Graphics.TEXT_JUSTIFY_CENTER);

        // Side columns: items from top 118, pitch 54.35 (icon 14 + value 19.55 + label 10.8 + gap 10).
        var values = [
            Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), Data.thousands(Data.calories()),
            Data.fmt(Data.bodyBattery()), Data.fmt(Data.stress()), Data.battery() + "%"
        ];
        var labels = ["BPM", "STEPS", "KCAL", "BODY", "STRESS", "BATT"];
        var icons = [:heart, :steps, :flame, :bolt, :pulse, :battery];
        var colors = [0xFF6B5A, accent, 0xFFB36B, 0x4DA3FF, 0xFF9F1C, 0xE6E6E6];
        var vf = fValue;
        var lf = fLabel;
        for (var i = 0; i < 6; i++) {
            var left = i < 3;
            var top = 118 + 54.35 * (i % 3);
            var label = labels[i] as String;
            if (left) {
                // right-aligned at x = 114
                Gfx.icon(dc, icons[i] as Symbol, 107, top + 7, 14, colors[i] as Number);
                Gfx.text(dc, 114, top + 23.8, vf, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_RIGHT);
                Gfx.text(dc, 114, top + 38.95, lf, label, 0x8A8A8A, Graphics.TEXT_JUSTIFY_RIGHT);
            } else {
                Gfx.icon(dc, icons[i] as Symbol, 283, top + 7, 14, colors[i] as Number);
                Gfx.text(dc, 276, top + 23.8, vf, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
                Gfx.text(dc, 276, top + 38.95, lf, label, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }

        // Footer (13px, gap 10): temp · arrows sunrise/sunset · notifications, cap center 337.8.
        var f = fFoot;
        var temp = Data.temperature();
        var tStr = temp != null ? temp + "°" : "--°";
        var rise = Data.timeOf(Data.sunrise());
        var set = Data.timeOf(Data.sunset());
        var notif = Data.fmt(Data.notifications()) + " NOTIF";
        var aw = 8;      // arrow glyph width
        var sp = 4;      // word space
        var wT = Gfx.width(dc, tStr, f);
        var wR = Gfx.width(dc, rise, f);
        var wS = Gfx.width(dc, set, f);
        var wN = Gfx.width(dc, notif, f);
        var total = wT + 10 + aw + wR + sp + aw + wS + 10 + wN;
        var x = 195 - total / 2;
        var y = 337.8;
        Gfx.text(dc, x, y, f, tStr, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
        x += wT + 10;
        drawArrow(dc, x + aw / 2.0, y, true, 0x9A9A9A);
        x += aw;
        Gfx.text(dc, x, y, f, rise, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        x += wR + sp;
        drawArrow(dc, x + aw / 2.0, y, false, 0x9A9A9A);
        x += aw;
        Gfx.text(dc, x, y, f, set, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        x += wS + 10;
        Gfx.text(dc, x, y, f, notif, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawArrow(dc as Dc, cx as Float, cy as Numeric, up as Boolean, color as Number) as Void {
        var tip = up ? cy - 5 : cy + 5;
        var tail = up ? cy + 5 : cy - 5;
        var wing = up ? tip + 3.5 : tip - 3.5;
        Gfx.line(dc, cx, tail, cx, tip, color, 1.3);
        Gfx.line(dc, cx - 3, wing, cx, tip, color, 1.3);
        Gfx.line(dc, cx + 3, wing, cx, tip, color, 1.3);
    }

    function drawAod(dc as Dc) as Void {
        Gfx.text(dc, 195, 47.8, fADate, Data.dateStr(), 0x7A7A7A, Graphics.TEXT_JUSTIFY_CENTER);

        // Hollow numerals: the ATime font is generated with a 2px outline (CSS text-stroke).
        var hm = timeStrings();
        Gfx.text(dc, 195, 125.2, fATime, hm[0], 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 251.6, fATime, hm[1], 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);

        // Footer (14px, gap 16), cap center 338.4.
        var f = fARow;
        var parts = ["HR " + Data.fmt(Data.heartRate()), "BB " + Data.fmt(Data.bodyBattery()), Data.battery() + "%"];
        var total = 32.0;
        for (var i = 0; i < 3; i++) { total += Gfx.width(dc, parts[i] as String, f); }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 338.4, f, parts[i] as String, 0x7A7A7A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, f) + 16;
        }
    }
}
