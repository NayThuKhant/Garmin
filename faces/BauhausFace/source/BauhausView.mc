import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face S · Bauhaus — mockups/Bauhaus.dc.html (active), mockups/BauhausAOD.dc.html (always-on).
class BauhausView extends WatchUi.WatchFace {

    const RED = 0xE63B2E;
    const BLUE = 0x2D5BD8;
    const WHITE = 0xEDEDED;

    var mSleep as Boolean = false;
    var fHead as FontResource;
    var fTime as FontResource;
    var fVal as FontResource;
    var fLab as FontResource;
    var fFoot as FontResource;
    var fAodDate as FontResource;
    var fAodTime as FontResource;
    var fAodRow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fVal = WatchUi.loadResource(Rez.Fonts.Val) as FontResource;
        fLab = WatchUi.loadResource(Rez.Fonts.Lab) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fAodTime = WatchUi.loadResource(Rez.Fonts.AodTime) as FontResource;
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

    // "10.08" centered at (195,cy), dot in its own color.
    // Letter-spacing (-3) is baked into the font.
    function drawTime(dc as Dc, cy as Numeric, f as FontResource, color as Number, dotColor as Number) as Void {
        var t = Data.clock();
        var parts = [Data.hourStr(t.hour as Number), ".", (t.min as Number).format("%02d")];
        var colors = [color, dotColor, color];
        var total = 0.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i], f);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, cy, f, parts[i], colors[i], Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i], f);
        }
    }

    // Shape glyphs on a 48-unit grid, top-left (ox,oy), scale sc, filled fraction fr (<0: outline only).
    function circleTile(dc as Dc, ox as Numeric, oy as Numeric, sc as Float, fr as Float, color as Number, w as Numeric) as Void {
        Gfx.arc(dc, ox + 24 * sc, oy + 24 * sc, 22 * sc, 0, 360, color, w);
        if (fr > 0) {
            Extra.pie(dc, ox + 24 * sc, oy + 24 * sc, 22 * sc, 0, 360 * fr, color);
        }
    }

    function squareTile(dc as Dc, ox as Numeric, oy as Numeric, sc as Float, fr as Float, color as Number, w as Numeric) as Void {
        Extra.strokePoly(dc, [ox + 2 * sc, oy + 2 * sc, ox + 46 * sc, oy + 2 * sc, ox + 46 * sc, oy + 46 * sc, ox + 2 * sc, oy + 46 * sc], color, w);
        if (fr > 0) {
            var h = 44 * fr * sc;
            Gfx.rect(dc, ox + 2 * sc, oy + 46 * sc - h, 44 * sc, h, color);
        }
    }

    function triangleTile(dc as Dc, ox as Numeric, oy as Numeric, sc as Float, fr as Float, color as Number, w as Numeric) as Void {
        Extra.strokePoly(dc, [ox + 24 * sc, oy + 2 * sc, ox + 46 * sc, oy + 46 * sc, ox + 2 * sc, oy + 46 * sc], color, w);
        if (fr > 0) {
            var h = 44 * fr;
            var inset = 22 * fr;
            Extra.fillPoly(dc, [ox + 2 * sc, oy + 46 * sc, ox + 46 * sc, oy + 46 * sc,
                                ox + (46 - inset) * sc, oy + (46 - h) * sc, ox + (2 + inset) * sc, oy + (46 - h) * sc], color);
        }
    }

    function domeTile(dc as Dc, ox as Numeric, oy as Numeric, fr as Float, color as Number) as Void {
        Gfx.arc(dc, ox + 24, oy + 40, 22, -90, 90, color, 1.5);
        Gfx.line(dc, ox + 2, oy + 40, ox + 46, oy + 40, color, 1.5);
        if (fr > 0) {
            Extra.pie(dc, ox + 24, oy + 40, 22, -90, -90 + 180 * fr, color);
        }
    }

    function drawActive(dc as Dc) as Void {
        // Accent (setting, default yellow): header square, time dot, stress triangle.
        var accent = Gfx.accent(0xF2C230);
        // Header row: red dot · date · temp · yellow square, gap 10, centered at y 56.6.
        var f11 = fHead;
        var date = Data.dateStr();
        var temp = Data.temperature();
        var tstr = temp != null ? temp + "°" : "--°";
        var w1 = Gfx.width(dc, date, f11);
        var w2 = Gfx.width(dc, tstr, f11);
        var x = 195 - (8 + 10 + w1 + 10 + w2 + 10 + 8) / 2;
        Extra.dot(dc, x + 4, 56.6, 4, RED);
        x += 18;
        Gfx.text(dc, x, 56.6, f11, date, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        x += w1 + 10;
        Gfx.text(dc, x, 56.6, f11, tstr, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
        x += w2 + 10;
        Gfx.rect(dc, x, 52.6, 8, 8, accent);

        drawTime(dc, 108.2, fTime, 0xFFFFFF, accent);

        // Four tiles: 48 wide, gap 16, top 163.2; value at 224.2, label at 242.
        var steps = Data.steps();
        var bb = Data.bodyBattery();
        var st = Data.stress();
        var batt = Data.battery();
        var ty = 163.2;
        circleTile(dc, 75, ty, 1.0, Extra.frac(steps, Data.stepGoal()), RED, 1.5);
        squareTile(dc, 139, ty, 1.0, Extra.frac(bb, 100), BLUE, 1.5);
        triangleTile(dc, 203, ty, 1.0, Extra.frac(st, 100), accent, 1.5);
        domeTile(dc, 267, ty, Extra.frac(batt, 100), WHITE);

        var stepsStr = "--";
        if (steps != null) {
            stepsStr = steps >= 1000 ? (steps / 1000.0).format("%.1f") + "k" : steps.toString();
        }
        var values = [stepsStr, Data.fmt(bb), Data.fmt(st), batt + "%"];
        var labels = ["STEPS", "BODY", "STRESS", "BATT"];
        var vf = fVal;
        var lf = fLab;
        for (var i = 0; i < 4; i++) {
            var cx = 99 + 64 * i;
            Gfx.text(dc, cx, 224.2, vf, values[i], 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, 242, lf, labels[i], 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer row.
        Extra.row(dc, 195, 270, fFoot,
            ["HR " + Data.fmt(Data.heartRate()), Data.thousands(Data.calories()) + " kcal", Extra.sunStr()],
            [RED, 0xD0D0D0, 0x8A8A8A], 12, 0, 9);
    }

    function drawAod(dc as Dc) as Void {
        var grey = 0x6A6A6A;
        Gfx.text(dc, 195, 135, fAodDate, Data.dateStr(), grey, Graphics.TEXT_JUSTIFY_CENTER);
        drawTime(dc, 192.6, fAodTime, 0xA8A8A8, 0xA8A8A8);

        var f13 = fAodRow;
        var txt = "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery());
        var tw = Gfx.width(dc, txt, f13);
        var x = 195 - (3 * 18 + 3 * 16 + tw) / 2;
        var y = 252.6 - 9;
        var sc = 18 / 48.0;
        circleTile(dc, x, y, sc, -1.0, grey, 1);
        squareTile(dc, x + 34, y, sc, -1.0, grey, 1);
        triangleTile(dc, x + 68, y, sc, -1.0, grey, 1);
        Gfx.text(dc, x + 102, 252.6, f13, txt, grey, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
