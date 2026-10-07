import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face U · Neon — mockups/Neon.dc.html (active), mockups/NeonAOD.dc.html (always-on).
class NeonView extends WatchUi.WatchFace {

    const CYAN = 0x4DE8FF;
    const CYAN_TXT = 0xD8FAFF;
    const PINK = 0xFF4D8D;
    const PINK_TXT = 0xFFE3EE;

    var mSleep as Boolean = false;
    var fDate as FontResource;
    var fTime as FontResource;
    var fRow as FontResource;
    var fRow2 as FontResource;
    var fFoot as FontResource;
    var fAodRow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fRow = WatchUi.loadResource(Rez.Fonts.Row) as FontResource;
        fRow2 = WatchUi.loadResource(Rez.Fonts.Row2) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
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

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    // Text groups of the active face. 0 date, 1 time, 2 HR/BB/ST, 3 steps/kcal.
    function group(dc as Dc, g as Number, color as Number) as Void {
        if (g == 0) {
            var temp = Data.temperature();
            Gfx.text(dc, 195, 105.8, fDate,
                Data.dateStr() + " · " + (temp != null ? temp + "°" : "--°"), color, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (g == 1) {
            Gfx.text(dc, 195, 169.4, fTime, timeStr(), color, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (g == 2) {
            Extra.row(dc, 195, 236, fRow,
                ["HR " + Data.fmt(Data.heartRate()), "BB " + Data.fmt(Data.bodyBattery()), "ST " + Data.fmt(Data.stress())],
                [color, color, color], 18, 0, 10);
        } else {
            Extra.row(dc, 195, 265, fRow2,
                [Data.thousands(Data.steps()) + " steps", Data.thousands(Data.calories()) + " kcal"],
                [color, color], 18, 0, 10);
        }
    }

    // Neon text: dim halo copies at small offsets (shifting Gfx.dx/dy), then the bright core.
    function glow(dc as Dc, g as Number, halo as Number, core as Number, r as Numeric) as Void {
        var ox = Gfx.dx;
        var oy = Gfx.dy;
        var rings = [[r, 0.22], [r / 2.0, 0.5]];
        for (var j = 0; j < 2; j++) {
            var d = rings[j][0] as Numeric;
            var c = Gfx.dim(halo, rings[j][1] as Float);
            var offs = [d, 0, -d, 0, 0, d, 0, -d];
            for (var i = 0; i < 8; i += 2) {
                Gfx.dx = ox + offs[i];
                Gfx.dy = oy + offs[i + 1];
                group(dc, g, c);
            }
        }
        Gfx.dx = ox;
        Gfx.dy = oy;
        group(dc, g, core);
    }

    function drawActive(dc as Dc) as Void {
        // Steps progress ring with layered glow.
        Gfx.arc(dc, 195, 195, 178, 0, 360, 0x101A1D, 3);
        var a1 = 360 * Extra.frac(Data.steps(), Data.stepGoal());
        Extra.capArc(dc, 195, 195, 178, 0, a1, Gfx.dim(CYAN, 0.18), 12);
        Extra.capArc(dc, 195, 195, 178, 0, a1, Gfx.dim(CYAN, 0.467), 6);
        Extra.capArc(dc, 195, 195, 178, 0, a1, CYAN_TXT, 2);

        glow(dc, 0, CYAN, CYAN_TXT, 1.5);
        glow(dc, 1, PINK, PINK_TXT, 3);
        glow(dc, 2, PINK, PINK_TXT, 1.5);
        glow(dc, 3, CYAN, CYAN_TXT, 1.5);

        Extra.row(dc, 195, 286.6, fFoot,
            [Extra.sunStr(), "BAT " + Data.battery() + "%", Data.fmt(Data.notifications()) + " NOTIF"],
            [0x7A8A90, 0x7A8A90, 0x7A8A90], 14, 1, 8);
    }

    function drawAod(dc as Dc) as Void {
        var a1 = 360 * Extra.frac(Data.steps(), Data.stepGoal());
        Extra.capArc(dc, 195, 195, 178, 0, a1, 0x3A5A60, 1.5);
        Gfx.text(dc, 195, 130.8, fDate, Data.dateStr(), 0x5A6A70, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 194.4, fTime, timeStr(), 0x9A8A90, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 258.6, fAodRow,
            "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery()), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
