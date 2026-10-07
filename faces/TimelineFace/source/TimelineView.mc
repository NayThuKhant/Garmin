import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;
import Toybox.WatchUi;

// Face K · Day timeline — mockups/Timeline.dc.html (active), mockups/TimelineAOD.dc.html (always-on).
// A 24h bar (00..24) shows elapsed day, scheduled sleep (purple) and active periods
// (accent: 15-min bins where heart rate reached zone 2), plus a "now" marker.
class TimelineView extends WatchUi.WatchFace {

    const BINS = 96;                       // 15-minute bins
    var mSleep as Boolean = false;
    var mActive as Array<Boolean> = [] as Array<Boolean>;
    var mActiveStamp as Number = -1;       // minute-of-day / 5 when mActive was computed

    var fHead as FontResource, fTime as FontResource, fBar as FontResource, fHours as FontResource, fValue as FontResource, fLabel as FontResource, fADate as FontResource, fATime as FontResource, fARow as FontResource;

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fBar = WatchUi.loadResource(Rez.Fonts.Bar) as FontResource;
        fHours = WatchUi.loadResource(Rez.Fonts.Hours) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fADate = WatchUi.loadResource(Rez.Fonts.ADate) as FontResource;
        fATime = WatchUi.loadResource(Rez.Fonts.ATime) as FontResource;
        fARow = WatchUi.loadResource(Rez.Fonts.ARow) as FontResource;
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

    // ---- data ----

    function nowMin() as Number {
        var c = System.getClockTime();
        return c.hour * 60 + c.min;
    }

    // Scheduled sleep window [startMin, endMin] in minutes since midnight, or null.
    function sleepWindow() as Array<Number> or Null {
        var p = UserProfile.getProfile();
        if (p == null || !(p has :sleepTime) || p.sleepTime == null || p.wakeTime == null) { return null; }
        var s = ((p.sleepTime as Time.Duration).value() / 60) % 1440;
        var w = ((p.wakeTime as Time.Duration).value() / 60) % 1440;
        return [s, w];
    }

    // Segments of scheduled sleep within today, clipped to now: flat [a0,b0,a1,b1,...] in minutes.
    function sleepSegs(now as Number) as Array<Number> {
        var out = [] as Array<Number>;
        var w = sleepWindow();
        if (w == null) { return out; }
        var s = w[0];
        var e = w[1];
        var segs = s > e ? [0, e, s, 1440] : [s, e];
        for (var i = 0; i < segs.size(); i += 2) {
            var a = segs[i];
            var b = segs[i + 1] < now ? segs[i + 1] : now;
            if (b > a) {
                out.add(a);
                out.add(b);
            }
        }
        return out;
    }

    function sleepLabel() as String {
        var w = sleepWindow();
        var dur = "--";
        if (w != null) {
            var m = (w[1] - w[0] + 1440) % 1440;
            dur = (m / 60) + "H " + (m % 60) + "M";
        }
        return "SLEEP " + dur + " · " + Data.fmt(sleepScore());
    }

    function sleepScore() as Number or Null {
        if (!(Toybox has :Complications)) { return null; }
        try {
            var c = Complications.getComplication(new Complications.Id(Complications.COMPLICATION_TYPE_SLEEP_SCORE));
            if (c != null && c.value instanceof Number) {
                return c.value as Number;
            }
        } catch (e) {
        }
        return null;
    }

    // Heart rate threshold for "active": top of zone 1 (start of zone 2).
    function activeHr() as Number {
        if (UserProfile has :getHeartRateZones) {
            var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            if (z != null && z.size() > 1 && z[1] != null) {
                return z[1] as Number;
            }
        }
        return 110;
    }

    // Recompute active bins from today's heart rate history at most every 5 minutes.
    function updateActive(now as Number) as Void {
        var stamp = now / 5;
        if (stamp == mActiveStamp) { return; }
        mActiveStamp = stamp;
        mActive = new Array<Boolean>[BINS];
        for (var i = 0; i < BINS; i++) { mActive[i] = false; }
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getHeartRateHistory)) { return; }
        var it = SensorHistory.getHeartRateHistory({:period => new Time.Duration(now * 60 + 60),
                                                    :order => SensorHistory.ORDER_NEWEST_FIRST});
        var thr = activeHr();
        var midnight = Time.today().value();
        var s = it.next();
        while (s != null) {
            if (s.data != null && s.when != null && (s.data as Numeric) >= thr) {
                var b = (s.when.value() - midnight) / 900;
                if (b >= 0 && b < BINS) { mActive[b] = true; }
            }
            s = it.next();
        }
    }

    function stepsShort(v as Number or Null) as String {
        if (v == null) { return "--"; }
        if (v < 1000) { return v.toString(); }
        return (v / 1000.0).format("%.1f") + "k";
    }

    function intensityToday() as Number or Null {
        var am = ActivityMonitor.getInfo();
        if ((am has :activeMinutesDay) && am.activeMinutesDay != null) {
            return am.activeMinutesDay.total;
        }
        return null;
    }

    // ---- drawing ----

    // Timeline bar contents at (x,y) width w height h.
    function drawSegs(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric,
                      now as Number, sleepColor as Number, activeColor as Number) as Void {
        var ss = sleepSegs(now);
        for (var i = 0; i < ss.size(); i += 2) {
            Gfx.rect(dc, x + w * ss[i] / 1440.0, y, w * (ss[i + 1] - ss[i]) / 1440.0, h, sleepColor);
        }
        updateActive(now);
        var i = 0;
        while (i < BINS) {
            if (mActive[i]) {
                var j = i;
                while (j < BINS && mActive[j]) { j++; }
                Gfx.rect(dc, x + w * i / BINS.toFloat(), y, w * (j - i) / BINS.toFloat(), h, activeColor);
                i = j;
            } else {
                i++;
            }
        }
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);
        var now = nowMin();

        // Header: date · temp · notifications (13px, spacing 1.5, gap 10), cap center 57.8.
        var small = fHead;
        var temp = Data.temperature();
        var parts = [Data.dateStr(), temp != null ? temp + "°" : "--°", Data.fmt(Data.notifications()) + " NOTIF"];
        var colors = [0x9A9A9A, 0xD0D0D0, 0x9A9A9A];
        var total = 20.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i] as String, small);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 57.8, small, parts[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, small) + 10;
        }

        var t = Data.clock();
        var time = Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
        Gfx.text(dc, 195, 106.45, fTime, time, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);

        // Bar labels (11px, spacing 1).
        var lf = fBar;
        Gfx.text(dc, 50, 153.9, lf, "TODAY", 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        var sl = sleepLabel();
        Gfx.text(dc, 340, 153.9, lf, sl, 0x9FA8FF, Graphics.TEXT_JUSTIFY_RIGHT);

        // Bar: x 50..340, top 164.5, height 14.
        var by = 164.5;
        dc.setColor(0x141414, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(Gfx.sx(50), Gfx.sy(by), Gfx.s(290), Gfx.s(14), Gfx.s(4));
        Gfx.rect(dc, 50, by, 290 * now / 1440.0, 14, 0x262626);
        drawSegs(dc, 50, by, 290, 14, now, 0x6B74C9, accent);
        Gfx.rect(dc, 50 + 290 * now / 1440.0, by - 4, 2, 22, 0xFFFFFF);

        // Hour labels, space-between over 290px, cap center 188.5.
        var hf = fHours;
        var hrs = ["00", "06", "12", "18", "24"];
        var sum = 0.0;
        for (var i = 0; i < 5; i++) { sum += Gfx.width(dc, hrs[i] as String, hf); }
        var gap = (290 - sum) / 4;
        x = 50.0;
        for (var i = 0; i < 5; i++) {
            Gfx.text(dc, x, 188.5, hf, hrs[i] as String, 0x6A6A6A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, hrs[i] as String, hf) + gap;
        }

        // 4x2 grid, columns 72.5 wide from x=50; rows from y=206.5 (pitch 40.6).
        var o2 = Data.spo2();
        var im = intensityToday();
        var values = [
            Data.fmt(Data.heartRate()),
            stepsShort(Data.steps()),
            Data.fmt(Data.bodyBattery()),
            Data.fmt(Data.stress()),
            Data.thousands(Data.calories()),
            o2 != null ? o2 + "%" : "--",
            im != null ? im + "m" : "--",
            Data.battery() + "%"
        ];
        var labels = ["BPM", "STEPS", "BODY", "STRESS", "KCAL", "SPO2", "INT MIN", "BATT"];
        var lcol = [0xFF6B5A, accent, 0x4DA3FF, 0xFF9F1C, 0xFFB36B, 0x4DD0E1, 0xB388FF, 0xD0D0D0];
        var vf = fValue;
        var lbf = fLabel;
        for (var i = 0; i < 8; i++) {
            var cx = 86.25 + 72.5 * (i % 4);
            var top = 206.5 + 40.6 * (i / 4);
            Gfx.text(dc, cx, top + 9.9, vf, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, top + 25.2, lbf, labels[i] as String, lcol[i] as Number, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawAod(dc as Dc) as Void {
        var now = nowMin();
        Gfx.text(dc, 195, 128.15, fADate, Data.dateStr(), 0x7A7A7A, Graphics.TEXT_JUSTIFY_CENTER);
        var t = Data.clock();
        var time = Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
        Gfx.text(dc, 195, 184.8, fATime, time, 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);

        drawSegs(dc, 75, 233.65, 240, 6, now, 0x3A3F66, 0x5A6A2A);

        var f = fARow;
        var parts = ["HR " + Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), "BB " + Data.fmt(Data.bodyBattery())];
        var total = 32.0;
        for (var i = 0; i < 3; i++) { total += Gfx.width(dc, parts[i] as String, f); }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 260.65, f, parts[i] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, f) + 16;
        }
    }
}
