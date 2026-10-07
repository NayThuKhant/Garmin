import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Face B · Data grid — mockups/DataGrid.dc.html (active), mockups/DataGridAOD.dc.html (always-on).
// Outer ring: steps vs goal. 2x2 tiles: HR, steps, body battery, battery.
class DataGridView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py).
    var fTime as FontResource;
    var fTimeAod as FontResource;
    var fDate as FontResource;
    var fDateAod as FontResource;
    var fValue as FontResource;
    var fLabel as FontResource;
    var fRowAod as FontResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fDateAod = WatchUi.loadResource(Rez.Fonts.DateAod) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fRowAod = WatchUi.loadResource(Rez.Fonts.RowAod) as FontResource;
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
        var steps = Data.steps();
        var fSteps = Ex.frac(steps, Data.stepGoal());
        var time = Data.hourStr(System.getClockTime().hour) + ":" + Ex.minStr();
        var hr = Data.heartRate();

        if (mSleep) {
            Ex.gauge(dc, 195, 195, 186, 0, 360, fSteps, null, Gfx.dim(accent, 0.4), 2);
            Gfx.text(dc, 195, 110, fTimeAod, time, 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, 195, 171.6, fDateAod, Data.dateStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
            Ex.iconRow(dc, 195, 227.2, fRowAod, [null, null, null], [0, 0, 0], [0, 0, 0],
                ["HR " + Data.fmt(hr), Data.thousands(steps), Data.battery() + "%"],
                [0x9A9A9A, 0x9A9A9A, 0x9A9A9A], 0, 28);
            Gfx.aodMask(dc);
            return;
        }

        Gfx.arc(dc, 195, 195, 186, 0, 360, 0x1F1F1F, 4);
        Ex.gauge(dc, 195, 195, 186, 0, 360, fSteps, null, accent, 4);

        // Column from padding-top 62: time 96px (lh 1), date 16px, grid 250 wide.
        Gfx.text(dc, 195, 110, fTime, time, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 171.6, fDate, Data.dateStr(), 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);

        var icons = [:heart, :steps, :bolt, :battery];
        var iconColors = [0xFF6B5A, accent, Ex.color("SecondaryColor", 0x4DA3FF), 0xD0D0D0];
        var values = [Data.fmt(hr), Data.thousands(steps), Data.fmt(Data.bodyBattery()), Data.battery() + "%"];
        var labels = ["BPM", "STEPS", "BODY BATT", "BATTERY"];
        for (var i = 0; i < 4; i++) {
            var left = 70 + (i % 2) * 130;
            var top = 203.2 + (i / 2) * 67.4;
            dc.setColor(0x141414, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(Gfx.sx(left), Gfx.sy(top), Gfx.s(120), Gfx.s(57.4), Gfx.s(14));
            Gfx.icon(dc, icons[i] as Symbol, left + 22, top + 28.7, 20, iconColors[i] as Number);
            Gfx.text(dc, left + 42, top + 22.1, fValue, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
            Gfx.text(dc, left + 42, top + 40.8, fLabel, labels[i] as String, 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }
}
