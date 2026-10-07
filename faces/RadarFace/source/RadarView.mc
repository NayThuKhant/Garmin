import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face T · Radar — mockups/Radar.dc.html (active), mockups/RadarAOD.dc.html (always-on).
class RadarView extends WatchUi.WatchFace {

    const CX = 195;
    const CY = 226;
    const R = 74;

    var mSleep as Boolean = false;
    var fHead as FontResource;
    var fTime as FontResource;
    var fSec as FontResource;
    var fVal as FontResource;
    var fLab as FontResource;
    var fHr as FontResource;
    var fBpm as FontResource;
    var fFoot as FontResource;
    var fAodDate as FontResource;
    var fAodFoot as FontResource;

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fSec = WatchUi.loadResource(Rez.Fonts.Sec) as FontResource;
        fVal = WatchUi.loadResource(Rez.Fonts.Val) as FontResource;
        fLab = WatchUi.loadResource(Rez.Fonts.Lab) as FontResource;
        fHr = WatchUi.loadResource(Rez.Fonts.Hr) as FontResource;
        fBpm = WatchUi.loadResource(Rez.Fonts.Bpm) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fAodFoot = WatchUi.loadResource(Rez.Fonts.AodFoot) as FontResource;
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

    // Last night's sleep score from the native complication, or null.
    function sleepScore() as Number or Null {
        if (!(Toybox has :Complications) || !(Complications has :getComplication)) { return null; }
        try {
            var c = Complications.getComplication(new Complications.Id(Complications.COMPLICATION_TYPE_SLEEP_SCORE));
            if (c != null && c.value instanceof Number) {
                return c.value as Number;
            }
        } catch (e) {
        }
        return null;
    }

    // Six axis fractions: steps, body, sleep, intensity, calm, SpO2 (clock 30°, 90° ... 330°).
    function fractions(steps, bb, sleep, inten, st, o2) as Array<Float> {
        var goal = Data.activeMinutesWeekGoal();
        return [
            Extra.frac(steps, Data.stepGoal()),
            Extra.frac(bb, 100),
            Extra.frac(sleep, 100),
            Extra.frac(inten, goal != null && goal > 0 ? goal : 150),
            st != null ? Extra.clamp01(1.0 - st / 100.0) : 0.0,
            Extra.frac(o2, 100)
        ];
    }

    function shape(fr as Array<Float>) as Array<Numeric> {
        var p = [] as Array<Numeric>;
        for (var i = 0; i < 6; i++) {
            var a = 30 + 60 * i;
            p.add(Gfx.px(CX, R * fr[i], a));
            p.add(Gfx.py(CY, R * fr[i], a));
        }
        return p;
    }

    function drawTime(dc as Dc, color as Number, secColor as Number or Null) as Void {
        var t = Data.clock();
        var f = fTime;
        var str = Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
        var w = Gfx.width(dc, str, f);
        var sf = fSec;
        var sec = " " + (t.sec as Number).format("%02d");
        var ws = secColor != null ? Gfx.width(dc, sec, sf) : 0;
        var x = 195 - (w + ws) / 2;
        Gfx.text(dc, x, 75.8, f, str, color, Graphics.TEXT_JUSTIFY_LEFT);
        x += w;
        if (secColor != null) {
            // Baseline-aligned with the big digits.
            Gfx.text(dc, x, 75.8 + 0.355 * (56 - 18), sf, sec, secColor, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0x7CF2C9);

        // Hex grid: 4 rings, 6 spokes.
        for (var k = 1; k <= 4; k++) {
            var p = [] as Array<Numeric>;
            for (var i = 0; i < 6; i++) {
                var a = 30 + 60 * i;
                p.add(Gfx.px(CX, 18.5 * k, a));
                p.add(Gfx.py(CY, 18.5 * k, a));
            }
            Extra.strokePoly(dc, p, 0x262626, 1);
        }
        for (var i = 0; i < 6; i++) {
            var a = 30 + 60 * i;
            Gfx.line(dc, CX, CY, Gfx.px(CX, R, a), Gfx.py(CY, R, a), 0x1E1E1E, 1);
        }

        var steps = Data.steps();
        var bb = Data.bodyBattery();
        var sleep = sleepScore();
        var inten = Data.activeMinutesWeek();
        var st = Data.stress();
        var o2 = Data.spo2();
        var p = shape(fractions(steps, bb, sleep, inten, st, o2));
        Extra.fillPoly(dc, p, Gfx.dim(accent, 0.16));
        Extra.strokePoly(dc, p, accent, 2);
        for (var i = 0; i < 12; i += 2) {
            Extra.dot(dc, p[i], p[i + 1], 3.5, accent);
        }

        // Axis labels (box centers / value + label cap centers).
        var values = [
            Data.thousands(steps), Data.fmt(bb), Data.fmt(sleep),
            inten != null ? inten + "m" : "--", st != null ? st + " str" : "--",
            o2 != null ? o2 + "%" : "--"
        ];
        var labels = ["STEPS", "BODY", "SLEEP", "INTENS", "CALM", "SPO2"];
        var xs = [245, 295, 245, 145, 95, 145];
        var ys = [125.4, 212, 298.6, 298.6, 212, 125.4];
        var vf = fVal;
        var lf = fLab;
        for (var i = 0; i < 6; i++) {
            Gfx.text(dc, xs[i], ys[i] + 7.15, vf, values[i], 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, xs[i], ys[i] + 19.1, lf, labels[i], 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Header: date · temp, then time with seconds.
        var temp = Data.temperature();
        Extra.row(dc, 195, 40.6, fHead, [Data.dateStr(), temp != null ? temp + "°" : "--°"],
            [0x9A9A9A, 0xD0D0D0], 10, 2, 8);
        drawTime(dc, 0xFFFFFF, accent);

        // Center heart rate.
        Gfx.text(dc, 195, 221.5, fHr, Data.fmt(Data.heartRate()), 0xFF6B5A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 233.2, fBpm, "BPM", 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);

        // Footer.
        Extra.row(dc, 195, 346.6, fFoot,
            [Data.thousands(Data.calories()) + " kcal", Data.battery() + "%", Data.fmt(Data.notifications()) + " notif"],
            [0x8A8A8A, 0xD0D0D0, 0x8A8A8A], 12, 0, 8);
    }

    function drawAod(dc as Dc) as Void {
        var p = shape(fractions(Data.steps(), Data.bodyBattery(), sleepScore(), Data.activeMinutesWeek(),
                                Data.stress(), Data.spo2()));
        Extra.strokePoly(dc, p, 0x5A5A5A, 1.5);
        Gfx.text(dc, 195, 40.6, fAodDate, Data.dateStr(), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
        drawTime(dc, 0xA8A8A8, null);
        Extra.row(dc, 195, 347.2, fAodFoot,
            ["HR " + Data.fmt(Data.heartRate()), "BB " + Data.fmt(Data.bodyBattery())],
            [0x6A6A6A, 0x6A6A6A], 14, 0, 8);
    }
}
