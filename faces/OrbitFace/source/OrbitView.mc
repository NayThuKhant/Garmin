import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face M · Orbit — mockups/Orbit.dc.html (active), mockups/OrbitAOD.dc.html (always-on).
// Four concentric orbits (steps/goal, body battery, stress, battery); each value is a
// planet at its clock angle, with a trail from 12 o'clock.
class OrbitView extends WatchUi.WatchFace {

    const RADII = [178, 158, 138, 118];
    var mSleep as Boolean = false;

    var fDate as FontResource, fTime as FontResource, fRow as FontResource, fGrid as FontResource, fADate as FontResource, fARow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fRow = WatchUi.loadResource(Rez.Fonts.Row) as FontResource;
        fGrid = WatchUi.loadResource(Rez.Fonts.Grid) as FontResource;
        fADate = WatchUi.loadResource(Rez.Fonts.ADate) as FontResource;
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

    // Fractions 0..1 (or null when unknown) for steps, body battery, stress, battery.
    function fractions() as Array {
        var st = Data.steps();
        var goal = Data.stepGoal();
        var bb = Data.bodyBattery();
        var sr = Data.stress();
        return [
            (st != null && goal != null && goal > 0) ? clamp(st.toFloat() / goal) : null,
            bb != null ? clamp(bb / 100.0) : null,
            sr != null ? clamp(sr / 100.0) : null,
            clamp(Data.battery() / 100.0)
        ];
    }

    function clamp(f as Float) as Float {
        return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
    }

    // "MON 05 OCT" -> "MON · 05 OCT"
    function dateDot() as String {
        var d = Data.dateStr();
        var i = d.find(" ");
        return i == null ? d : d.substring(0, i) + " ·" + d.substring(i, d.length());
    }

    function timeParts() as Array<String> {
        var t = Data.clock();
        return [Data.hourStr(t.hour as Number), (t.min as Number).format("%02d")];
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);
        var colors = [accent, 0x4DA3FF, 0xFF9F1C, 0xE6E6E6];
        var fr = fractions();

        for (var i = 0; i < 4; i++) {
            var r = RADII[i] as Number;
            var c = colors[i] as Number;
            Gfx.arc(dc, 195, 195, r, 0, 360, 0x1C1C1C, 1.5);
            if (fr[i] != null) {
                var a = 360 * (fr[i] as Float);
                Gfx.arc(dc, 195, 195, r, 0, a, Gfx.dim(c, 0.55), 1.5);
                var x = Gfx.sx(Gfx.px(195, r, a));
                var y = Gfx.sy(Gfx.py(195, r, a));
                dc.setColor(Gfx.dim(c, 0.14), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, Gfx.s(11));
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, Gfx.s(5.5));
            }
        }
        // 12 hour ticks at r 188.
        dc.setColor(0x4A4A4A, Graphics.COLOR_TRANSPARENT);
        var tr = Gfx.s(1.2);
        for (var i = 0; i < 12; i++) {
            dc.fillCircle(Gfx.sx(Gfx.px(195, 188, i * 30)), Gfx.sy(Gfx.py(195, 188, i * 30)), tr < 1 ? 1 : tr);
        }

        // Center column (flex, centered): date 136, time 176.2, info row 217, grid rows 238.8 / 254.
        Gfx.text(dc, 195, 136, fDate, dateDot(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);

        var tf = fTime;
        var hm = timeParts();
        var full = hm[0] + ":" + hm[1];
        var x = 195 - Gfx.width(dc, full, tf) / 2;
        Gfx.text(dc, x, 176.2, tf, hm[0], 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
        x += Gfx.width(dc, hm[0], tf);
        Gfx.text(dc, x, 176.2, tf, ":", accent, Graphics.TEXT_JUSTIFY_LEFT);
        x += Gfx.width(dc, ":", tf);
        Gfx.text(dc, x, 176.2, tf, hm[1], 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);

        var rf = fRow;
        var temp = Data.temperature();
        var parts = ["HR " + Data.fmt(Data.heartRate()), temp != null ? temp + "°" : "--°",
                     Data.fmt(Data.notifications()) + " notif"];
        var pc = [0xFF6B5A, 0xD0D0D0, 0x8A8A8A];
        var total = 20.0;
        for (var i = 0; i < 3; i++) { total += Gfx.width(dc, parts[i] as String, rf); }
        x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 217, rf, parts[i] as String, pc[i] as Number, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, rf) + 10;
        }

        // 2x2 legend grid: dot 6 + gap 4 + text; equal columns, column gap 10.
        var gf = fGrid;
        var bb = Data.bodyBattery();
        var sr = Data.stress();
        var items = [
            Data.thousands(Data.steps()) + " steps",
            Data.fmt(bb) + " body",
            Data.fmt(sr) + " stress",
            Data.battery() + "% batt"
        ];
        var colW = 0.0;
        for (var i = 0; i < 4; i++) {
            var w = 10 + Gfx.width(dc, items[i] as String, gf);
            if (w > colW) { colW = w; }
        }
        var left = 195 - (2 * colW + 10) / 2;
        for (var i = 0; i < 4; i++) {
            var cx = left + (i % 2) * (colW + 10);
            var cy = i < 2 ? 238.8 : 254;
            dc.setColor(colors[i] as Number, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(Gfx.sx(cx + 3), Gfx.sy(cy), Gfx.s(3));
            Gfx.text(dc, cx + 10, cy, gf, items[i] as String, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    function drawAod(dc as Dc) as Void {
        var fr = fractions();
        dc.setColor(0x6A6A6A, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            if (fr[i] != null) {
                var r = RADII[i] as Number;
                var a = 360 * (fr[i] as Float);
                dc.fillCircle(Gfx.sx(Gfx.px(195, r, a)), Gfx.sy(Gfx.py(195, r, a)), Gfx.s(4));
            }
        }
        Gfx.arc(dc, 195, 195, 178, 0, 360, 0x141414, 1);

        Gfx.text(dc, 195, 152.2, fADate, dateDot(), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
        var hm = timeParts();
        Gfx.text(dc, 195, 194.4, fTime, hm[0] + ":" + hm[1], 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 237.2, fARow,
                 "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery()),
                 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
