import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face X · Dot matrix — mockups/DotMatrix.dc.html (active), mockups/DotMatrixAOD.dc.html (always-on).
class DotMatrixView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // 5x7 digit glyphs (0-9), one 5-bit row per entry, MSB = leftmost column.
    // 0/1/8 match the mockup (slashed zero).
    const GLYPHS = [
        0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E,   // 0
        0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E,   // 1
        0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F,   // 2
        0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E,   // 3
        0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02,   // 4
        0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E,   // 5
        0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E,   // 6
        0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08,   // 7
        0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E,   // 8
        0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C    // 9
    ];

    // Mockup font (DotGothic16) as bitmap fonts (faces/DotMatrixFace/fonts.json, tools/mkfont.py).
    var fHead as FontResource;
    var fGrid as FontResource;
    var fNotif as FontResource;

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fGrid = WatchUi.loadResource(Rez.Fonts.Grid) as FontResource;
        fNotif = WatchUi.loadResource(Rez.Fonts.Notif) as FontResource;
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

    // 25x7 matrix bitmap of HH:MM as 7 row masks (bit 24 = column 0).
    // Digits at columns 0, 6, 14, 20; colon at column 12, rows 2 and 4.
    function matrixRows() as Array<Number> {
        var t = Data.clock();
        var h = t.hour as Number;
        var hs = Data.hourStr(h);
        var m = t.min as Number;
        var digits = [hs.length() > 1 ? hs.substring(0, 1).toNumber() : null,
                      hs.substring(hs.length() - 1, hs.length()).toNumber(), m / 10, m % 10];
        var cols = [0, 6, 14, 20];
        var rows = [0, 0, 0, 0, 0, 0, 0] as Array<Number>;
        for (var d = 0; d < 4; d++) {
            var v = digits[d];
            if (v == null) { continue; }
            for (var r = 0; r < 7; r++) {
                rows[r] = rows[r] | ((GLYPHS[(v as Number) * 7 + r] as Number) << (20 - (cols[d] as Number)));
            }
        }
        rows[2] = rows[2] | (1 << 12);
        rows[4] = rows[4] | (1 << 12);
        return rows;
    }

    // Draw the dot grid at x=75+10c, y=118+10r. Unlit dots only when offColor != null.
    function drawMatrix(dc as Dc, onColor as Number, onR as Float, offColor as Number or Null) as Void {
        var rows = matrixRows();
        for (var r = 0; r < 7; r++) {
            for (var c = 0; c < 25; c++) {
                var on = (rows[r] & (1 << (24 - c))) != 0;
                if (on) {
                    dc.setColor(onColor, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(Gfx.sx(75 + 10 * c), Gfx.sy(118 + 10 * r), onR * Gfx.k);
                } else if (offColor != null) {
                    dc.setColor(offColor, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(Gfx.sx(75 + 10 * c), Gfx.sy(118 + 10 * r), 1.6 * Gfx.k);
                }
            }
        }
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xFFB000);

        var temp = Data.temperature();
        Gfx.text(dc, 195, 85, fHead,
            Data.dateStr() + " " + (temp != null ? temp + "°" : "--°"), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);

        drawMatrix(dc, accent, 3.3, 0x161616);

        // Step-goal progress: 30 dots at y=206 from x=93.5, pitch 7.
        var steps = Data.steps();
        var goal = Data.stepGoal();
        var lit = 0;
        if (steps != null && goal != null && goal > 0) {
            lit = steps * 30 / goal;
            if (lit > 30) { lit = 30; }
        }
        for (var i = 0; i < 30; i++) {
            dc.setColor(i < lit ? 0xFFFFFF : 0x1E1E1E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(Gfx.sx(93.5 + 7 * i), Gfx.sy(206), 2 * Gfx.k);
        }

        // 3x3 data grid: left 75, width 240, col gap 12 -> columns 72 wide; rows 16.8 + gap 4.
        var st = steps == null ? "--"
            : (steps < 1000 ? steps.toString() : (steps / 1000.0).format("%.1f") + "k");
        var o2 = Data.spo2();
        var labels = ["HR", "ST", "KC", "BB", "SR", "O2", "↑", "↓", "BT"];
        var values = [
            Data.fmt(Data.heartRate()), st, Data.fmt(Data.calories()),
            Data.fmt(Data.bodyBattery()), Data.fmt(Data.stress()), Data.fmt(o2),
            Data.timeOf(Data.sunrise()), Data.timeOf(Data.sunset()), Data.battery().toString()
        ];
        var colors = [0xFF6B5A, accent, 0xE6E6E6, 0x4DA3FF, 0xFF9F1C, 0xE6E6E6, 0xE6E6E6, 0xE6E6E6, 0xE6E6E6];
        var f = fGrid;
        for (var i = 0; i < 9; i++) {
            var x0 = 75 + 84 * (i % 3);
            var cy = 234.4 + 20.8 * (i / 3);
            Gfx.text(dc, x0, cy, f, labels[i] as String, 0x6A6A6A, Graphics.TEXT_JUSTIFY_LEFT);
            Gfx.text(dc, x0 + 72, cy, f, values[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var n = Data.notifications();
        Gfx.text(dc, 195, 311.2, fNotif, Data.fmt(n) + " NOTIFICATIONS", 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawAod(dc as Dc) as Void {
        Gfx.text(dc, 195, 85, fHead, Data.dateStr(), 0x5A5A5A, Graphics.TEXT_JUSTIFY_CENTER);
        drawMatrix(dc, 0x7A7A7A, 2.6, null);
        var f = fGrid;
        var a = "HR " + Data.fmt(Data.heartRate());
        var b = "BB " + Data.fmt(Data.bodyBattery());
        var wa = Gfx.width(dc, a, f);
        var x = 195 - (wa + 16 + Gfx.width(dc, b, f)) / 2;
        Gfx.text(dc, x, 234.4, f, a, 0x5A5A5A, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + wa + 16, 234.4, f, b, 0x5A5A5A, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
