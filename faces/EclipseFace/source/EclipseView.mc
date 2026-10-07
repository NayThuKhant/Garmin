import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face Y · Eclipse — mockups/Eclipse.dc.html (active), mockups/EclipseAOD.dc.html (always-on).
// An accent disc (r150 at 190,188) eclipsed by a black disc of the same size. The black
// disc's offset follows the battery level: 9 px (mockup look) at >= 80 %, down to 3 px at 0 %.
class EclipseView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    const DEF_ACCENT = 0xFFB347;
    const CX = 190;
    const CY = 188;
    const R = 150;

    // 19 rays: x1,y1,x2,y2 (design units) and stroke opacity (percent).
    const RAYS = [
        43.4, 241.4, 32.1, 245.5,   37.7, 221.8, 22.7, 225.1,   34.6, 201.6, 22.2, 202.7,
        34.1, 181.2, 23.9, 180.7,   36.4, 160.9, 19.7, 158.0,   41.2, 141.1, 22.5, 135.2,
        48.6, 122.1, 37.9, 117.1,   58.4, 104.2, 47.8, 97.4,    70.5, 87.7, 52.4, 72.5,
        84.6, 73.0, 70.3, 57.4,     100.5, 60.2, 94.6, 51.8,    118.0, 49.6, 110.7, 35.7,
        136.6, 41.4, 129.1, 20.7,   156.2, 35.7, 153.0, 21.3,   176.4, 32.6, 175.5, 22.5,
        196.8, 32.1, 197.5, 16.7,   217.1, 34.4, 219.9, 18.4,   236.9, 39.2, 240.2, 28.6,
        255.9, 46.6, 260.4, 37.1
    ];
    const RAY_OP = [30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30];

    // Mockup fonts as bitmap fonts (faces/EclipseFace/fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fDate as FontResource;
    var fInfo as FontResource;
    var fSteps as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fInfo = WatchUi.loadResource(Rez.Fonts.Info) as FontResource;
        fSteps = WatchUi.loadResource(Rez.Fonts.Steps) as FontResource;
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

    // Eclipse offset in design px: lo at 0 % battery, hi at >= 80 %.
    function offset(lo as Float, hi as Float) as Float {
        var b = Data.battery();
        var f = b >= 80 ? 1.0 : (b <= 0 ? 0.0 : b / 80.0);
        return lo + (hi - lo) * f;
    }

    function disc(dc as Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(x), Gfx.sy(y), Gfx.s(r));
    }

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    function drawActive(dc as Dc) as Void {
        var acc = Gfx.accent(DEF_ACCENT);

        // Halo: 6 % ring, then 16 % over it (0.16 + 0.84 * 0.06 = 21 %), then the solid disc.
        disc(dc, CX, CY, 159, Gfx.dim(acc, 0.06));
        disc(dc, CX, CY, 154, Gfx.dim(acc, 0.21));
        disc(dc, CX, CY, R, acc);

        for (var i = 0; i < 19; i++) {
            var j = i * 4;
            Gfx.line(dc, RAYS[j], RAYS[j + 1], RAYS[j + 2], RAYS[j + 3],
                     Gfx.dim(acc, RAY_OP[i] / 100.0), 1.2);
        }

        var o = offset(3.0, 9.0);
        disc(dc, CX + o, CY + o, R, 0x000000);

        // Point at clock 315 on the rim.
        disc(dc, 83.9, 81.9, 11, Gfx.dim(0xFFFFFF, 0.18));
        disc(dc, 83.9, 81.9, 4.5, 0xFFFFFF);

        Gfx.text(dc, 199, 133.5, fDate, Data.dateStr(), 0x8C7B66, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 199, 184, fTime, timeStr(), 0xF6F1E8, Graphics.TEXT_JUSTIFY_CENTER);

        // "62 BPM   68 BODY   82%" — values #B9AE9F, units #6E6255, gap 14.
        var parts = [
            Data.fmt(Data.heartRate()) + " ", "BPM",
            Data.fmt(Data.bodyBattery()) + " ", "BODY",
            Data.battery().toString(), "%"
        ];
        var total = 28.0;
        for (var i = 0; i < 6; i++) {
            total += Gfx.width(dc, parts[i] as String, fInfo);
        }
        var x = 199 - total / 2;
        for (var i = 0; i < 6; i++) {
            var str = parts[i] as String;
            Gfx.text(dc, x, 246.2, fInfo, str, i % 2 == 0 ? 0xB9AE9F : 0x6E6255, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, str, fInfo);
            if (i % 2 == 1) { x += 14; }
        }

        Gfx.text(dc, 199, 274.8, fSteps, Data.thousands(Data.steps()) + " STEPS", acc, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawAod(dc as Dc) as Void {
        var o = offset(2.0, 6.0);
        disc(dc, CX, CY, R, 0x3A3A3A);
        disc(dc, CX + o, CY + o, R, 0x000000);

        Gfx.text(dc, 196, 133.5, fDate, Data.dateStr(), 0x5E5E5E, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 196, 184, fTime, timeStr(), 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 196, 246.2, fInfo,
                 Data.fmt(Data.heartRate()) + " BPM · " + Data.fmt(Data.bodyBattery()) + " BODY",
                 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
