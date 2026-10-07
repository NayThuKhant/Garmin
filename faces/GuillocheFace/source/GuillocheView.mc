import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face R · Guilloché — mockups/Guilloche.dc.html (active), mockups/GuillocheAOD.dc.html (always-on).
class GuillocheView extends WatchUi.WatchFace {

    const GOLD = 0xD4B26A;

    var mSleep as Boolean = false;
    var fDow as FontResource;
    var fDay as FontResource;
    var fDayAod as FontResource;
    var fSub as FontResource;
    var fRow as FontResource;
    var fVal as FontResource;
    var fLab as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDow = WatchUi.loadResource(Rez.Fonts.Dow) as FontResource;
        fDay = WatchUi.loadResource(Rez.Fonts.Day) as FontResource;
        fDayAod = WatchUi.loadResource(Rez.Fonts.DayAod) as FontResource;
        fSub = WatchUi.loadResource(Rez.Fonts.Sub) as FontResource;
        fRow = WatchUi.loadResource(Rez.Fonts.Row) as FontResource;
        fVal = WatchUi.loadResource(Rez.Fonts.Val) as FontResource;
        fLab = WatchUi.loadResource(Rez.Fonts.Lab) as FontResource;
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

    // Hand outline in hand-local coords (along, perp) rotated to clock angle `a` around the center.
    function handPts(a as Float, local as Array<Numeric>) as Array<Numeric> {
        var sn = Math.sin(Math.toRadians(a));
        var cs = Math.cos(Math.toRadians(a));
        var out = [] as Array<Numeric>;
        for (var i = 0; i + 1 < local.size(); i += 2) {
            var al = local[i];
            var pp = local[i + 1];
            out.add(195 + al * sn + pp * cs);
            out.add(195 - al * cs + pp * sn);
        }
        return out;
    }

    // Hour hand: tail 14, half-width 8 at 24, tip 96. Minute: tail 14, half-width 6 at 38, tip 152.
    function hourHand(a as Float) as Array<Numeric> {
        return handPts(a, [-14, 0, 24, -8, 96, 0, 24, 8]);
    }
    function minuteHand(a as Float) as Array<Numeric> {
        return handPts(a, [-14, 0, 38, -6, 152, 0, 38, 6]);
    }

    function angles() as [Float, Float] {
        var t = Data.clock();
        var h = (t.hour as Number) % 12;
        var m = t.min as Number;
        return [(h * 30 + m * 0.5).toFloat(), (m * 6).toFloat()];
    }

    function dateWindow(dc as Dc, border as Number, txt as Number, f as FontResource) as Void {
        dc.setColor(border, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(Gfx.sx(276), Gfx.sy(181), Gfx.s(44), Gfx.s(28), Gfx.s(3));
        var day = (Data.clock().day as Number).format("%02d");
        Gfx.text(dc, 298, 195, f, day, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawActive(dc as Dc) as Void {
        // Guilloché rosette: 36 circles r=46 whose centers lie on a circle r=46.
        var rose = Gfx.dim(GOLD, 0.22);
        dc.setColor(rose, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i < 36; i++) {
            var a = i * 10;
            dc.drawCircle(Gfx.sx(Gfx.px(195, 46, a)), Gfx.sy(Gfx.py(195, 46, a)), Gfx.s(46));
        }
        Gfx.arc(dc, 195, 195, 172, 0, 360, Gfx.dim(GOLD, 0.35), 0.8);

        // Minute ticks r178..184.
        for (var i = 0; i < 60; i++) {
            if (i % 5 == 0) { continue; }
            var a = i * 6;
            Gfx.line(dc, Gfx.px(195, 184, a), Gfx.py(195, 184, a), Gfx.px(195, 178, a), Gfx.py(195, 178, a), 0x5A4E33, 1);
        }
        // Hour markers r162..184 (double at 12, none at 3 — date window).
        for (var h = 1; h < 12; h++) {
            if (h == 3) { continue; }
            var a = h * 30;
            Extra.capLine(dc, Gfx.px(195, 184, a), Gfx.py(195, 184, a), Gfx.px(195, 162, a), Gfx.py(195, 162, a), GOLD, 4);
        }
        var d12 = [-2.21, 2.21];
        for (var i = 0; i < 2; i++) {
            var a = d12[i];
            Extra.capLine(dc, Gfx.px(195, 184, a), Gfx.py(195, 184, a), Gfx.px(195, 158, a), Gfx.py(195, 158, a), GOLD, 4);
        }

        // Heart-rate sub-dial at (92,195): 240° sweep from 240° to 120° (clock), 40..180 bpm.
        Gfx.arc(dc, 92, 195, 34, 0, 360, Gfx.dim(GOLD, 0.6), 1);
        for (var i = 0; i < 8; i++) {
            var a = 240 + i * 240 / 7.0;
            Gfx.line(dc, Gfx.px(92, 34, a), Gfx.py(195, 34, a), Gfx.px(92, 29, a), Gfx.py(195, 29, a), GOLD, 1);
        }
        var hr = Data.heartRate();
        if (hr != null) {
            var ha = 240 + 240 * Extra.clamp01((hr - 40) / 140.0);
            Extra.capLine(dc, 92, 195, Gfx.px(92, 27, ha), Gfx.py(195, 27, ha), 0xFFFFFF, 1.6);
        }
        Extra.dot(dc, 92, 195, 2.5, 0xFFFFFF);

        // Reserve (battery) arc at (195,296) r=34, -60°..60°.
        var batt = Data.battery();
        Extra.capArc(dc, 195, 296, 34, -60, 60, 0x3A3324, 5);
        Extra.capArc(dc, 195, 296, 34, -60, -60 + 120 * Extra.clamp01(batt / 100.0), GOLD, 5);

        // Header.
        var dow = Data.weekday();
        Gfx.text(dc, 195, 77.2, fDow, dow, GOLD, Graphics.TEXT_JUSTIFY_CENTER);
        var temp = Data.temperature();
        Extra.row(dc, 195, 96.4, fSub, [(temp != null ? temp + "°" : "--°") + " · " + Extra.sunStr()], [0x8A7A55], 0, 2, 8);

        // Steps / body / stress row.
        Extra.row(dc, 195, 134, fRow,
            [Data.thousands(Data.steps()) + " STEPS", "BODY " + Data.fmt(Data.bodyBattery()), "STR " + Data.fmt(Data.stress())],
            [0x8A7A55, 0x8A7A55, 0x8A7A55], 12, 1.5, 8);

        dateWindow(dc, GOLD, 0xF2EAD6, fDay);

        // Sub-dial and reserve labels.
        Gfx.text(dc, 92, 244.4, fVal, Data.fmt(hr), 0xF2EAD6, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 92, 258.2, fLab, "BPM", 0x8A7A55, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 308.4, fVal, batt + "%", 0xF2EAD6, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 322.2, fLab, "RESERVE", 0x8A7A55, Graphics.TEXT_JUSTIFY_CENTER);

        // Hands.
        var an = angles();
        var hp = hourHand(an[0]);
        Extra.fillPoly(dc, hp, GOLD);
        Extra.fillPoly(dc, hp.slice(0, 6), 0xDFC58F);
        var mp = minuteHand(an[1]);
        Extra.fillPoly(dc, mp, GOLD);
        Extra.fillPoly(dc, mp.slice(0, 6), 0xDFC58F);

        // Seconds hand (awake only): 160 forward, 30 tail.
        var sa = (Data.clock().sec as Number) * 6;
        Gfx.line(dc, Gfx.px(195, -30, sa), Gfx.py(195, -30, sa), Gfx.px(195, 160, sa), Gfx.py(195, 160, sa), 0xE8E2D0, 1.2);
        Extra.dot(dc, 195, 195, 6, GOLD);
        Extra.dot(dc, 195, 195, 2, 0x000000);
    }

    function drawAod(dc as Dc) as Void {
        for (var h = 0; h < 12; h++) {
            if (h == 3) { continue; }
            var a = h * 30;
            Extra.capLine(dc, Gfx.px(195, 184, a), Gfx.py(195, 184, a), Gfx.px(195, 166, a), Gfx.py(195, 166, a), 0x6A5A38, 2.5);
        }
        dateWindow(dc, 0x5A4E33, 0x8A7A55, fDayAod);
        var an = angles();
        Extra.strokePoly(dc, hourHand(an[0]), 0xA08A5A, 1.2);
        Extra.strokePoly(dc, minuteHand(an[1]), 0xA08A5A, 1.2);
        Extra.dot(dc, 195, 195, 4, 0xA08A5A);
    }
}
