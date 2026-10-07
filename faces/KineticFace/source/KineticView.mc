import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Face Q · Kinetic type — mockups/Kinetic.dc.html (active), mockups/KineticAOD.dc.html (always-on).
class KineticView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py). The rim text stays on
    // the vector font because drawRadialText needs one.
    // The 172px fonts are big, so only the current mode's set is kept in memory.
    var fBig as FontResource or Null = null;
    var fBigOut as FontResource or Null = null;
    var fSec as FontResource or Null = null;
    var fBigOutAod as FontResource or Null = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onEnterSleep() as Void {
        mSleep = true;
        fBig = null;
        fBigOut = null;
        fSec = null;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mSleep = false;
        fBigOutAod = null;
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

    // Text running clockwise along the rim (textPath r=176 starting at 12 o'clock),
    // letter-spaced, glyphs drawn one by one. Stops before it wraps onto itself.
    function rimText(dc as Dc, str as String, color as Number) as Void {
        var f = Gfx.font(Gfx.SANS, 10.5);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = 179.5;                       // cap centre: baseline 176 + half cap height
        var rpx = r * Gfx.k;
        var chars = str.toCharArray();
        var radial = (dc has :drawRadialText) && (f instanceof Graphics.VectorFont);
        var travelled = 0.0;                 // degrees clockwise from 12 o'clock
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toString();
            var w = dc.getTextWidthInPixels(c, f);
            if (travelled + Math.toDegrees(w / rpx) > 354) { break; }
            if (radial) {
                dc.drawRadialText(Gfx.sx(195), Gfx.sy(195), f as Graphics.VectorFont, c,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER,
                    90 - travelled, Gfx.s(r), Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            } else {
                var mid = travelled + Math.toDegrees(w / 2.0 / rpx);
                Gfx.text(dc, Gfx.px(195, r, mid), Gfx.py(195, r, mid), f, c, color, Graphics.TEXT_JUSTIFY_CENTER);
            }
            travelled += Math.toDegrees((w + 1.6 * Gfx.k) / rpx);
        }
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xFF4D8D);
        var t = Data.clock();

        if (fBig == null) {
            fBig = WatchUi.loadResource(Rez.Fonts.Big) as FontResource;
            fBigOut = WatchUi.loadResource(Rez.Fonts.BigOut) as FontResource;
            fSec = WatchUi.loadResource(Rez.Fonts.Sec) as FontResource;
        }
        // Hour: hollow (2px text-stroke), box top 62, line-height 0.85 -> cap centre 135.1.
        Gfx.text(dc, 92, 135.1, fBigOut as FontResource, Data.hourStr(t.hour as Number), 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
        // Minute: solid accent, box top 168 -> cap centre 241.1.
        Gfx.text(dc, 168, 241.1, fBig as FontResource, (t.min as Number).format("%02d"), accent, Graphics.TEXT_JUSTIFY_LEFT);
        // Seconds (awake only), 18px, box top 238.
        Gfx.text(dc, 116, 248.8, fSec as FontResource, (t.sec as Number).format("%02d"), 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);

        var temp = Data.temperature();
        var sep = "  ·  ";
        var s = Data.dateStr() + sep + (temp != null ? temp + "°" : "--°")
            + sep + "RISE " + Data.timeOf(Data.sunrise()) + "  SET " + Data.timeOf(Data.sunset())
            + sep + "HR " + Data.fmt(Data.heartRate())
            + sep + Data.thousands(Data.steps()) + " STEPS"
            + sep + "BODY " + Data.fmt(Data.bodyBattery())
            + sep + "STRESS " + Data.fmt(Data.stress())
            + sep + Data.thousands(Data.calories()) + " KCAL"
            + sep + "BAT " + Data.battery() + "%"
            + sep + Data.fmt(Data.notifications()) + " NOTIF" + sep;
        rimText(dc, s, 0x9A9A9A);
    }

    function drawAod(dc as Dc) as Void {
        var t = Data.clock();
        if (fBigOutAod == null) {
            fBigOutAod = WatchUi.loadResource(Rez.Fonts.BigOutAod) as FontResource;
        }
        var big = fBigOutAod as FontResource;
        Gfx.text(dc, 92, 135.1, big, Data.hourStr(t.hour as Number), 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, 168, 241.1, big, (t.min as Number).format("%02d"), 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        var sep = "  ·  ";
        rimText(dc, Data.dateStr() + sep + "HR " + Data.fmt(Data.heartRate()) + sep + "BODY "
            + Data.fmt(Data.bodyBattery()) + sep + "BAT " + Data.battery() + "%", 0x5A5A5A);
    }
}
