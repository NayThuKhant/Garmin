import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face Z · Polar — mockups/Polar.dc.html (active), mockups/PolarAOD.dc.html (always-on).
// Four concentric 330-degree rings from 12 o'clock: hour (12 h), minute, weekday (Mon..Sun),
// day of month. Labels sit right-aligned at x=182 in each ring's gap.
class PolarView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    const SPAN = 330.0;
    const RADII = [170, 148, 126, 104];
    const COLORS = [0xFF6B5A, 0xFFB347, 0x5EEAD4, 0xA78BFA];
    const TRACK = 0x151515;
    const DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    // Mockup fonts as bitmap fonts (faces/PolarFace/fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fLabel as FontResource;
    var fInfo as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fInfo = WatchUi.loadResource(Rez.Fonts.Info) as FontResource;
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
        var t = Data.clock();
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var hour = t.hour as Number;
        var min = t.min as Number;
        var dow = t.day_of_week as Number;        // 1 = Sunday
        var wd = dow == 1 ? 7 : dow - 1;          // Mon = 1 .. Sun = 7
        var day = t.day as Number;
        var mon = t.month as Number;
        var year = t.year as Number;
        var dim = DAYS[mon - 1] as Number;
        if (mon == 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))) { dim = 29; }

        var fr = [((hour % 12) + min / 60.0) / 12.0, min / 60.0, wd / 7.0, day / dim.toFloat()];
        var time = Data.hourStr(hour) + ":" + min.format("%02d");

        if (mSleep) {
            Gfx.aodShift();
            for (var i = 0; i < 4; i++) {
                ring(dc, RADII[i], 0, SPAN * fr[i], 0x5A5A5A, 2);
            }
            Gfx.text(dc, 195, 188, fTime, time, 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, 195, 223, fInfo, Data.dateStr(), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.aodMask(dc);
            return;
        }

        for (var i = 0; i < 4; i++) {
            ring(dc, RADII[i], 0, SPAN, TRACK, 14);
            ring(dc, RADII[i], 0, SPAN * fr[i], COLORS[i], 14);
        }

        var h12 = hour % 12;
        if (h12 == 0) { h12 = 12; }
        var labels = [
            h12.format("%02d") + " HR",
            min.format("%02d") + " MIN",
            (m.day_of_week as String).toUpper(),
            day.format("%02d") + " " + (m.month as String).toUpper()
        ];
        for (var i = 0; i < 4; i++) {
            Gfx.text(dc, 182, 195 - RADII[i], fLabel, labels[i] as String, COLORS[i], Graphics.TEXT_JUSTIFY_RIGHT);
        }

        Gfx.text(dc, 195, 188, fTime, time, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);

        // "62 bpm  82%" centred, gap 10.
        var hr = Data.fmt(Data.heartRate()) + " bpm";
        var bat = Data.battery() + "%";
        var w1 = Gfx.width(dc, hr, fInfo);
        var x = 195 - (w1 + 10 + Gfx.width(dc, bat, fInfo)) / 2;
        Gfx.text(dc, x, 223, fInfo, hr, 0xFF6B5A, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + w1 + 10, 223, fInfo, bat, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }

    // Arc on the centred circle radius r from clock angle a0 to a1, stroke w, round caps
    // (dc.drawArc has none, so both ends get a filled circle).
    function ring(dc as Dc, r as Number, a0 as Numeric, a1 as Numeric, color as Number, w as Numeric) as Void {
        Gfx.arc(dc, 195, 195, r, a0, a1, color, w);
        var cr = Gfx.s(w) / 2.0;
        if (cr < 1) { cr = 1; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(Gfx.px(195, r, a0)), Gfx.sy(Gfx.py(195, r, a0)), cr);
        dc.fillCircle(Gfx.sx(Gfx.px(195, r, a1)), Gfx.sy(Gfx.py(195, r, a1)), cr);
    }
}
