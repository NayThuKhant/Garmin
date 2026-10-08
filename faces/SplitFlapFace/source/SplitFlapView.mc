import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Face W · Split-flap — mockups/SplitFlap.dc.html (active), mockups/SplitFlapAOD.dc.html (always-on).
class SplitFlapView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (faces/SplitFlapFace/fonts.json, tools/mkfont.py).
    var fFlap as FontResource;
    var fMini as FontResource;
    var fHead as FontResource;
    var fLabel as FontResource;
    var fFoot as FontResource;
    var fAodInfo as FontResource;

    function initialize() {
        WatchFace.initialize();
        fFlap = WatchUi.loadResource(Rez.Fonts.Flap) as FontResource;
        fMini = WatchUi.loadResource(Rez.Fonts.Mini) as FontResource;
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
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

    // One flap tile at design (x,y) of size w x h with character `ch`.
    // Active: dark tile with lighter top half; AOD (outline): 1px border only.
    function tile(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, ch as String,
                  f as Graphics.FontType, color as Number, outline as Boolean) as Void {
        var r = Gfx.s(4);
        if (outline) {
            dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(Gfx.sx(x), Gfx.sy(y), Gfx.s(w), Gfx.s(h), r);
        } else {
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(Gfx.sx(x), Gfx.sy(y), Gfx.s(w), Gfx.s(h), r);
            // Upper flap: rounded top corners, square bottom.
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            var mid = Gfx.sy(y + h / 2.0);
            dc.fillRoundedRectangle(Gfx.sx(x), Gfx.sy(y), Gfx.s(w), mid - Gfx.sy(y) + r, r);
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(Gfx.sx(x), mid, Gfx.s(w), r);
        }
        if (!ch.equals(" ")) {
            Gfx.text(dc, x + w / 2.0, y + h / 2.0, f, ch, color, Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Split line (2px at h/2 - 1).
        Gfx.rect(dc, x, y + h / 2.0 - 1, w, 2, outline ? 0x1A1A1A : 0x000000);
    }

    // Big HH:MM row, 238 wide centered, top y. Colon dots at x=195.
    function drawTime(dc as Dc, y as Numeric, digitColor as Number, dotColor as Number, outline as Boolean) as Void {
        var t = Data.clock();
        var h = Data.hourStr(t.hour as Number);
        if (h.length() < 2) { h = " " + h; }
        var m = (t.min as Number).format("%02d");
        var f = fFlap;
        var xs = [76, 133, 205, 262];
        var chars = [h.substring(0, 1), h.substring(1, 2), m.substring(0, 1), m.substring(1, 2)];
        for (var i = 0; i < 4; i++) {
            tile(dc, xs[i] as Number, y, 52, 80, chars[i] as String, f, digitColor, outline);
        }
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(195), Gfx.sy(y + 30), Gfx.s(3));
        dc.fillCircle(Gfx.sx(195), Gfx.sy(y + 50), Gfx.s(3));
    }

    // Fit a value into 4 flap characters, right-aligned ("--" when missing).
    function four(v as Number or Null) as String {
        var s = v == null ? "--" : (v < 10000 ? v.toString() : (v / 1000) + "K");
        while (s.length() < 4) { s = " " + s; }
        return s.length() > 4 ? s.substring(s.length() - 4, s.length()) : s;
    }

    // "5:58" -> "05:58"
    function pad(s as String) as String {
        return s.length() == 4 ? "0" + s : s;
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xFFC94D);
        // Header, 11px spacing 3, box top 58.
        var temp = Data.temperature();
        var unit = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? "°F" : "°C";
        Gfx.text(dc, 195, 64.6, fHead,
            Data.dateStr() + " · " + (temp != null ? temp + unit : "--" + unit), accent, Graphics.TEXT_JUSTIFY_CENTER);

        drawTime(dc, 81.2, 0xF2F2F2, accent, false);

        // 3x2 grid of 4-tile counters; columns 62 wide, gap 14 -> centers 119/195/271.
        var labels = ["HR", "STEPS", "KCAL", "BODY", "STRESS", "BATT"];
        var values = [Data.heartRate(), Data.steps(), Data.calories(), Data.bodyBattery(), Data.stress(), Data.battery()];
        var lf = fLabel;
        var tf = fMini;
        for (var i = 0; i < 6; i++) {
            var cx = 119 + 76 * (i % 3);
            var top = 179.2 + 42.6 * (i / 3);
            Gfx.text(dc, cx, top + 4.8, lf, labels[i] as String, accent, Graphics.TEXT_JUSTIFY_CENTER);
            var s = four(values[i] as Number or Null);
            for (var j = 0; j < 4; j++) {
                tile(dc, cx - 31 + 16 * j, top + 12.6, 14, 20, s.substring(j, j + 1), tf, 0xF2F2F2, false);
            }
        }

        // Footer: sun times + notifications, 10px spacing 1.5, gap 14, top 268.4.
        var ff = fFoot;
        var sun = "SUN " + pad(Data.timeOf(Data.sunrise())) + " – " + pad(Data.timeOf(Data.sunset()));
        var notif = "NOTIF " + Data.fmt(Data.notifications());
        var w1 = Gfx.width(dc, sun, ff);
        var w2 = Gfx.width(dc, notif, ff);
        var x = 195 - (w1 + 14 + w2) / 2;
        Gfx.text(dc, x, 274.4, ff, sun, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + w1 + 14, 274.4, ff, notif, accent, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawAod(dc as Dc) as Void {
        Gfx.text(dc, 195, 135.8, fHead, Data.dateStr(), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
        drawTime(dc, 154.4, 0x9A9A9A, 0x6A6A6A, true);
        Gfx.text(dc, 195, 253.6, fAodInfo,
            "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery()), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
