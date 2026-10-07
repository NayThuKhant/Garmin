import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Face A · Ring — mockups/Main.dc.html (active), mockups/RingAOD.dc.html (always-on).
// Left arc: steps vs goal (accent). Right arc: body battery (secondary).
class RingView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fTimeAod as FontResource;
    var fDate as FontResource;
    var fDateAod as FontResource;
    var fValue as FontResource;
    var fSmall as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fDateAod = WatchUi.loadResource(Rez.Fonts.DateAod) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fSmall = WatchUi.loadResource(Rez.Fonts.Small) as FontResource;
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
        }
        var accent = Gfx.accent(0xC6F432);
        var secondary = Ex.color("SecondaryColor", 0x4DA3FF);
        var steps = Data.steps();
        var bb = Data.bodyBattery();
        var fSteps = Ex.frac(steps, Data.stepGoal());
        var fBb = Ex.frac(bb, 100);
        var hour = Data.hourStr(System.getClockTime().hour);

        if (mSleep) {
            // Arcs r=178: left 200->340 clock deg, right 160->20.
            Ex.gauge(dc, 195, 195, 178, 200, 340, fSteps, null, Gfx.dim(accent, 0.45), 3);
            Ex.gauge(dc, 195, 195, 178, 160, 20, fBb, null, Gfx.dim(secondary, 0.45), 3);
            Gfx.text(dc, 195, 129, fDateAod, Data.dateStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, 195, 207.8, fTimeAod, hour + ":" + Ex.minStr(), 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.aodMask(dc);
            return;
        }

        Ex.gauge(dc, 195, 195, 178, 200, 340, fSteps, 0x262626, accent, 8);
        Ex.gauge(dc, 195, 195, 178, 160, 20, fBb, 0x262626, secondary, 8);

        // Centered column (gap 4): date 18px, time 128px, icon row 22px.
        Gfx.text(dc, 195, 110.8, fDate, Data.dateStr(), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);
        Ex.pieces(dc, 195, 189.6, fTime, [hour, ":", Ex.minStr()], [0xFFFFFF, 0x5A5A5A, accent]);
        Ex.iconRow(dc, 195, 276.8, fValue,
            [:heart, :battery], [20, 22], [0xFF6B5A, 0xD0D0D0],
            [Data.fmt(Data.heartRate()), Data.battery() + "%"], [0xFFFFFF, 0xFFFFFF], 6, 22);

        // Bottom row at top 300: steps (accent), body battery (secondary).
        Ex.iconRow(dc, 195, 308.4, fSmall,
            [:steps, :bolt], [16, 16], [accent, secondary],
            [Data.thousands(steps), Data.fmt(bb)], [accent, secondary], 6, 28);
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }
}
