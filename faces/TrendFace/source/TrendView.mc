import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Face F · Health trend — mockups/Trend.dc.html (active), mockups/TrendAOD.dc.html (always-on).
class TrendView extends WatchUi.WatchFace {

    const BINS = 24;           // 4 h in 10-minute buckets

    var mSleep as Boolean = false;
    var fHead as FontResource;
    var fTime as FontResource;
    var fHrLabel as FontResource;
    var fRange as FontResource;
    var fBpm as FontResource;
    var fBpmTag as FontResource;
    var fValue as FontResource;
    var fLabel as FontResource;
    var fFoot as FontResource;
    var fAodDate as FontResource;
    var fAodTime as FontResource;
    var fAodRow as FontResource;
    var mHr as Array = [];     // BINS entries, Number or null (oldest first)
    var mHrMin as Number or Null = null;
    var mHrMax as Number or Null = null;
    var mHrKey as Number = -1; // minute the cache was built

    function initialize() {
        WatchFace.initialize();
        fHead = WatchUi.loadResource(Rez.Fonts.Head) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fHrLabel = WatchUi.loadResource(Rez.Fonts.HrLabel) as FontResource;
        fRange = WatchUi.loadResource(Rez.Fonts.Range) as FontResource;
        fBpm = WatchUi.loadResource(Rez.Fonts.Bpm) as FontResource;
        fBpmTag = WatchUi.loadResource(Rez.Fonts.BpmTag) as FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fFoot = WatchUi.loadResource(Rez.Fonts.Foot) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fAodTime = WatchUi.loadResource(Rez.Fonts.AodTime) as FontResource;
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
        loadHr();
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

    // Heart rate of the last 4 h averaged into 10-minute buckets (cached per minute).
    function loadHr() as Void {
        var now = Time.now().value();
        var key = now / 60;
        if (key == mHrKey) { return; }
        mHrKey = key;
        var sum = [] as Array<Number>;
        var cnt = [] as Array<Number>;
        for (var i = 0; i < BINS; i++) {
            sum.add(0);
            cnt.add(0);
        }
        mHrMin = null;
        mHrMax = null;
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(new Time.Duration(4 * 3600), true);
            var s = it.next();
            while (s != null) {
                var hr = s.heartRate;
                if (hr != null && hr != ActivityMonitor.INVALID_HR_SAMPLE && s.when != null) {
                    var age = now - s.when.value();
                    if (age >= BINS * 600) { break; }
                    var b = BINS - 1 - (age < 0 ? 0 : age / 600);
                    sum[b] += hr as Number;
                    cnt[b] += 1;
                    if (mHrMin == null || hr < mHrMin) { mHrMin = hr; }
                    if (mHrMax == null || hr > mHrMax) { mHrMax = hr; }
                }
                s = it.next();
            }
        }
        var out = new [BINS];
        for (var i = 0; i < BINS; i++) {
            if (cnt[i] > 0) { out[i] = sum[i] / cnt[i]; }
        }
        mHr = out;
    }

    // Sparkline in a 212x40 viewBox scaled into (ox, oy, w, h) design px.
    function spark(dc as Dc, ox as Numeric, oy as Numeric, w as Numeric, h as Numeric,
                   color as Number, pen as Numeric, fill as Number or Null) as Void {
        if (mHrMin == null || mHrMax == null) { return; }
        var lo = (mHrMin as Number) - 4;
        var hi = (mHrMax as Number) + 4;
        if (hi - lo < 30) {
            var mid = (hi + lo) / 2.0;
            lo = mid - 15;
            hi = mid + 15;
        }
        var kx = w / 212.0;
        var ky = h / 40.0;
        var xs = [] as Array<Float>;
        var ys = [] as Array<Float>;
        for (var i = 0; i < BINS; i++) {
            var v = mHr[i];
            if (v != null) {
                xs.add((ox + (2 + i * 208.0 / (BINS - 1)) * kx).toFloat());
                ys.add((oy + (37 - (v - lo) / (hi - lo).toFloat() * 34) * ky).toFloat());
            }
        }
        var n = xs.size();
        if (n < 2) { return; }
        if (fill != null) {
            var pts = [] as Array<Graphics.Point2D>;
            for (var i = 0; i < n; i++) {
                pts.add([Gfx.sx(xs[i]), Gfx.sy(ys[i])]);
            }
            pts.add([Gfx.sx(xs[n - 1]), Gfx.sy(oy + h)]);
            pts.add([Gfx.sx(xs[0]), Gfx.sy(oy + h)]);
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(pts);
        }
        for (var i = 1; i < n; i++) {
            Gfx.line(dc, xs[i - 1], ys[i - 1], xs[i], ys[i], color, pen);
        }
    }

    function drawActive(dc as Dc) as Void {
        var accent = Gfx.accent(0xC6F432);

        // Header (top 46): date · temp · notif, 14px, letter-spacing 1.5, gap 12.
        Ext.row(dc, 195, 54.4, fHead, 14,
            [Data.dateStr(), Ext.tempStr(), Data.fmt(Data.notifications()) + " NOTIF"],
            [0x9A9A9A, 0xD0D0D0, 0x9A9A9A], [12, 12]);

        // Time 88px condensed, line-height 0.95 (box 64.8..148.4).
        var t = System.getClockTime();
        Gfx.text(dc, 195, 106.6, fTime,
            Data.hourStr(t.hour) + ":" + t.min.format("%02d"), 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);

        // Heart-rate block, width 268 (x 61..329).
        Gfx.text(dc, 61, 161, fHrLabel, "HEART RATE · 4H", 0x9A9A9A, Graphics.TEXT_JUSTIFY_LEFT);
        var range = (mHrMin != null && mHrMax != null) ? mHrMin + "–" + mHrMax : "--";
        Gfx.text(dc, 329, 161, fRange, range, 0x8A8A8A, Graphics.TEXT_JUSTIFY_RIGHT);
        spark(dc, 61, 169.6, 212, 40, 0xFF6B5A, 2, Gfx.dim(0xFF6B5A, 0.15));
        Gfx.text(dc, 281, 183.6, fBpm, Data.fmt(Data.heartRate()), 0xFFFFFF, Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, 281, 202.6, fBpmTag, "BPM", 0xFF6B5A, Graphics.TEXT_JUSTIFY_LEFT);

        // 3x2 tile grid, width 280 (x 55..335), gap 6, tile height 39.5, radius 10.
        var im = Data.activeMinutesWeek();
        var img = Data.activeMinutesWeekGoal();
        var values = [
            Data.thousands(Data.steps()),
            Data.thousands(Data.calories()),
            Data.fmt(im) + "/" + Data.fmt(img),
            Data.fmt(Data.bodyBattery()),
            Data.fmt(Data.stress()),
            Data.fmt(Ext.sleepScore())
        ];
        var labels = ["STEPS", "KCAL", "INT MIN", "BODY BATT", "STRESS", "SLEEP"];
        var colors = [accent, 0xFFB36B, 0xB388FF, 0x4DA3FF, 0xFF9F1C, 0x9FA8FF];
        var cw = (280 - 12) / 3.0;
        for (var i = 0; i < 6; i++) {
            var col = i % 3;
            var top = 219.6 + (i / 3) * 45.5;
            var left = 55 + col * (cw + 6);
            dc.setColor(0x141414, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(Gfx.sx(left), Gfx.sy(top), Gfx.s(cw), Gfx.s(39.5), Gfx.s(10));
            var cx = left + cw / 2;
            Gfx.text(dc, cx, top + 14.35, fValue, values[i] as String, 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);
            Gfx.text(dc, cx, top + 29.1, fLabel, labels[i] as String, colors[i] as Number, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer: sunrise sunset · battery, 12px.
        Ext.row(dc, 195, 319.8, fFoot, 12,
            ["↑" + Data.timeOf(Data.sunrise()), "↓" + Data.timeOf(Data.sunset()), Data.battery() + "%"],
            [0x9A9A9A, 0x9A9A9A, 0xD0D0D0], [4, 10]);
    }

    function drawAod(dc as Dc) as Void {
        // Column centered vertically, gap 8: date (16.8), time (83.6), spark (28), row (18).
        Gfx.text(dc, 195, 118.2, fAodDate,
            Data.dateStr() + " · " + Ext.tempStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        var t = System.getClockTime();
        Gfx.text(dc, 195, 176.4, fAodTime,
            Data.hourStr(t.hour) + ":" + t.min.format("%02d"), 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
        spark(dc, 105, 226.2, 180, 28, 0x7A7A7A, 1.7, null);
        Ext.row(dc, 195, 271.2, fAodRow, 15,
            ["HR " + Data.fmt(Data.heartRate()), Data.thousands(Data.steps()), "BB " + Data.fmt(Data.bodyBattery())],
            [0x8A8A8A, 0x8A8A8A, 0x8A8A8A], [16, 16]);
    }
}
