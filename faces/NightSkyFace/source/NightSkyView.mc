import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face V · Night sky — mockups/NightSky.dc.html (active), mockups/NightSkyAOD.dc.html (always-on).
class NightSkyView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (faces/NightSkyFace/fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fHead as FontResource;
    var fValue as FontResource;
    var fLabel as FontResource;
    var fFoot as FontResource;
    var fAodHead as FontResource;
    var fAodInfo as FontResource;

    // Star field: x, y, radius, opacity (design units), from the mockup SVG.
    const STARS = [
        136.9, 65.6, 0.6, 0.35,  100.9, 47.7, 1.3, 0.35,  49.5, 180.1, 0.8, 0.35,  313.3, 103.9, 0.8, 0.35,
        255.1, 52.4, 0.8, 0.7,   62.2, 220.5, 0.6, 0.5,   334.7, 123.8, 0.8, 0.5,   260.7, 91.4, 1.0, 0.9,
        69.0, 139.4, 1.0, 0.5,   338.0, 140.4, 0.6, 0.7,  51.4, 225.8, 1.0, 0.9,    250.7, 30.2, 1.3, 0.7,
        85.5, 56.3, 0.6, 0.5,    283.5, 59.7, 0.8, 0.9,   56.6, 148.0, 1.0, 0.5,    88.2, 88.0, 0.8, 0.35,
        47.8, 272.3, 1.3, 0.9,   161.7, 52.6, 1.3, 0.35,  175.4, 54.3, 0.6, 0.35,   63.5, 124.4, 0.6, 0.35,
        79.0, 93.6, 1.0, 0.7,    186.5, 55.8, 1.3, 0.9,   331.7, 233.2, 1.0, 0.35,  259.7, 96.1, 1.0, 0.5,
        147.4, 85.5, 1.0, 0.5,   280.2, 77.9, 0.8, 0.9,   274.2, 86.6, 1.3, 0.7,    63.7, 153.7, 1.0, 0.5
    ];

    // Back and front mountain ridges (x, y pairs), closed along the bottom edge.
    const RIDGE_BACK = [0, 318, 48, 292, 86, 306, 130, 270, 168, 298, 205, 280, 246, 304, 290, 266, 330, 296, 390, 284];
    const RIDGE_FRONT = [0, 336, 60, 314, 110, 330, 170, 306, 230, 330, 280, 312, 340, 334, 390, 322];

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
        fAodHead = WatchUi.loadResource(Rez.Fonts.AodHead) as FontResource;
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

    // Moon age as a fraction of the synodic month (0 = new, 0.5 = full).
    function moonAge() as Float {
        var days = (Time.now().value() - 947182440) / 86400.0;   // since new moon 2000-01-06 18:14 UTC
        var age = days / 29.530588;
        return (age - Math.floor(age)).toFloat();
    }

    // Illuminated fraction 0..1.
    function moonIllum(age as Float) as Float {
        return ((1 - Math.cos(2 * Math.PI * age)) / 2).toFloat();
    }

    // Lit disc at (284,76) r22 with a black occluder slid sideways by phase
    // (mockup: occluder r21 at (272,73)). Waxing = lit on the right.
    function drawMoon(dc as Dc, color as Number) as Void {
        var age = moonAge();
        var off = age < 0.5 ? -44 * age / 0.5 : 44 * (1 - (age - 0.5) / 0.5);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(284), Gfx.sy(76), Gfx.s(22));
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(284 + off), Gfx.sy(73), Gfx.s(21));
    }

    function ridgePoly(pts as Array<Numeric>) as Array<[Numeric, Numeric]> {
        var out = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < pts.size(); i += 2) {
            out.add([Gfx.sx(pts[i]), Gfx.sy(pts[i + 1])]);
        }
        out.add([Gfx.sx(390), Gfx.sy(390)]);
        out.add([Gfx.sx(0), Gfx.sy(390)]);
        return out;
    }

    // "MONDAY · 05 OCT"
    function longDate() as String {
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Data.weekday() + " · " + (m.day as Number).format("%02d") + " "
            + (m.month as String).toUpper();
    }

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    function drawActive(dc as Dc) as Void {
        // Stars
        for (var i = 0; i < STARS.size(); i += 4) {
            dc.setColor(Gfx.dim(0xFFFFFF, STARS[i + 3].toFloat()), Graphics.COLOR_TRANSPARENT);
            var r = STARS[i + 2] * Gfx.k;
            dc.fillCircle(Gfx.sx(STARS[i]), Gfx.sy(STARS[i + 1]), r < 1 ? 1 : r);
        }

        // Moon: faint glow, then disc + phase occluder.
        dc.setColor(Gfx.dim(0xE8E3D3, 0.06), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(284), Gfx.sy(76), Gfx.s(34));
        drawMoon(dc, 0xE8E3D3);

        // Mountains
        dc.setColor(0x0E1426, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(ridgePoly(RIDGE_BACK));
        dc.setColor(0x070A14, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(ridgePoly(RIDGE_FRONT));

        // Moon label, right-aligned at x=250 (CSS trailing letter-spacing -> 248.5).
        var lf = fLabel;
        var moon = "MOON " + Math.round(moonIllum(moonAge()) * 100).toNumber() + "%";
        Gfx.text(dc, 250, 75.8, lf, moon, 0x7A83A0, Graphics.TEXT_JUSTIFY_RIGHT);

        // Header: date + temperature, 11px, spacing 3, box top 108.
        var temp = Data.temperature();
        Gfx.text(dc, 195, 114.6, fHead,
            longDate() + " · " + (temp != null ? temp + "°" : "--°"), 0x9AA3C0, Graphics.TEXT_JUSTIFY_CENTER);

        // Time, italic 100px, line-height 95 below the 13.2px header.
        Gfx.text(dc, 195, 168.7, fTime, timeStr(), 0xF4EFE2, Graphics.TEXT_JUSTIFY_CENTER);

        // 3-column stats, 240 wide centered.
        var vf = fValue;
        var values = [Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), Data.fmt(Data.bodyBattery())];
        var colors = [0xFF8A7A, 0xFFFFFF, 0x8FB7FF];
        var labels = ["BPM", "STEPS", "BODY"];
        for (var i = 0; i < 3; i++) {
            var cx = 115 + 80 * i;
            Gfx.text(dc, cx, 231.2, vf, values[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, 245, lf, labels[i] as String, 0x7A83A0, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer: STR · sunrise/sunset · battery, 11px, gap 12, top 330.
        var ff = fFoot;
        var parts = [
            "STR " + Data.fmt(Data.stress()),
            "↑" + Data.timeOf(Data.sunrise()) + " ↓" + Data.timeOf(Data.sunset()),
            Data.battery() + "%"
        ];
        var colors2 = [0x7A83A0, 0x7A83A0, 0xC0C6D8];
        var total = 24.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i] as String, ff);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 336.6, ff, parts[i] as String, colors2[i] as Number, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, ff) + 12;
        }
    }

    function drawAod(dc as Dc) as Void {
        drawMoon(dc, 0x5A574E);

        // Back ridge as a thin outline only.
        for (var i = 2; i < RIDGE_BACK.size(); i += 2) {
            Gfx.line(dc, RIDGE_BACK[i - 2], RIDGE_BACK[i - 1], RIDGE_BACK[i], RIDGE_BACK[i + 1], 0x1E2438, 1.5);
        }

        Gfx.text(dc, 195, 114.6, fAodHead, longDate(), 0x5A6078, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 168.7, fTime, timeStr(), 0xA8A49A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 231.4, fAodInfo,
            "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery()),
            0x5A6078, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
