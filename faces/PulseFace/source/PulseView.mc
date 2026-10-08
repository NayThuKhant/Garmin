import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Face P · 24h pulse ring — mockups/Pulse.dc.html (active), mockups/PulseAOD.dc.html (always-on).
// 48 ticks = 24 h of heart rate in 30-min buckets. "Now" is the dot at 12 o'clock; the
// ring runs clockwise from 24 h ago (just right of 12) to the latest half hour (just left).
class PulseView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;
    var mBuckets as Array<Number or Null> = new Array<Number or Null>[48];
    var mMin as Number or Null = null;
    var mMax as Number or Null = null;
    var mLastCalc as Number = 0;

    // Gradient stops for the active ring (t = position between 24h min and max).
    const STOP_T = [0.0, 0.3, 0.6, 0.85, 1.0] as Array<Float>;
    const STOP_C = [0x3B6FD9, 0x4DD0E1, 0xC6F432, 0xFF9F1C, 0xFF6448] as Array<Number>;

    // Mockup fonts as bitmap fonts (fonts.json, tools/mkfont.py).
    var fDate as FontResource;
    var fDateAod as FontResource;
    var fTime as FontResource;
    var fHr as FontResource;
    var fRange as FontResource;
    var fStats as FontResource;
    var fAod as FontResource;

    function initialize() {
        WatchFace.initialize();
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fDateAod = WatchUi.loadResource(Rez.Fonts.DateAod) as FontResource;
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        fHr = WatchUi.loadResource(Rez.Fonts.Hr) as FontResource;
        fRange = WatchUi.loadResource(Rez.Fonts.Range) as FontResource;
        fStats = WatchUi.loadResource(Rez.Fonts.Stats) as FontResource;
        fAod = WatchUi.loadResource(Rez.Fonts.Aod) as FontResource;
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
        updateHistory();
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

    // Average HR per 30-min bucket over the last 24 h (index 0 = oldest), plus 24 h min/max.
    // Recomputed at most every 5 minutes.
    function updateHistory() as Void {
        var now = Time.now().value();
        if (mLastCalc != 0 && now - mLastCalc < 300) { return; }
        mLastCalc = now;
        var sums = new Array<Number>[48];
        var counts = new Array<Number>[48];
        for (var i = 0; i < 48; i++) { sums[i] = 0; counts[i] = 0; mBuckets[i] = null; }
        mMin = null;
        mMax = null;
        if (!(ActivityMonitor has :getHeartRateHistory)) { return; }
        var it = ActivityMonitor.getHeartRateHistory(new Time.Duration(86400), true);
        var s = it.next();
        while (s != null) {
            var hr = s.heartRate;
            if (hr != null && hr != ActivityMonitor.INVALID_HR_SAMPLE && s.when != null) {
                var age = now - (s.when as Time.Moment).value();
                if (age >= 0 && age < 86400) {
                    var b = 47 - age / 1800;
                    sums[b] = (sums[b] as Number) + hr;
                    counts[b] = (counts[b] as Number) + 1;
                    if (mMin == null || hr < mMin) { mMin = hr; }
                    if (mMax == null || hr > mMax) { mMax = hr; }
                } else if (age >= 86400) {
                    break;
                }
            }
            s = it.next();
        }
        for (var i = 0; i < 48; i++) {
            if ((counts[i] as Number) > 0) {
                mBuckets[i] = (sums[i] as Number) / (counts[i] as Number);
            }
        }
    }

    // 0..1 position of a bucket value between the 24 h min and max.
    function level(v as Number) as Float {
        if (mMin == null || mMax == null || mMax <= mMin) { return 0.5; }
        var t = (v - mMin).toFloat() / (mMax - mMin);
        return t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
    }

    function gradient(t as Float) as Number {
        for (var i = 1; i < STOP_T.size(); i++) {
            if (t <= STOP_T[i]) {
                var u = (t - STOP_T[i - 1]) / (STOP_T[i] - STOP_T[i - 1]);
                var c0 = STOP_C[i - 1];
                var c1 = STOP_C[i];
                var r = ((c0 >> 16) & 0xFF) + (((c1 >> 16) & 0xFF) - ((c0 >> 16) & 0xFF)) * u;
                var g = ((c0 >> 8) & 0xFF) + (((c1 >> 8) & 0xFF) - ((c0 >> 8) & 0xFF)) * u;
                var b = (c0 & 0xFF) + ((c1 & 0xFF) - (c0 & 0xFF)) * u;
                return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
            }
        }
        return STOP_C[STOP_C.size() - 1];
    }

    // Radial tick at clock angle `deg` from radius r0, length len, round caps.
    function tick(dc as Dc, deg as Float, r0 as Numeric, len as Numeric, color as Number, w as Numeric) as Void {
        var x1 = Gfx.px(195, r0, deg);
        var y1 = Gfx.py(195, r0, deg);
        var x2 = Gfx.px(195, r0 + len, deg);
        var y2 = Gfx.py(195, r0 + len, deg);
        Gfx.line(dc, x1, y1, x2, y2, color, w);
        var cap = Gfx.s(w) / 2;
        if (cap >= 1) {
            dc.fillCircle(Gfx.sx(x1), Gfx.sy(y1), cap);
            dc.fillCircle(Gfx.sx(x2), Gfx.sy(y2), cap);
        }
    }

    function timeStr() as String {
        var t = Data.clock();
        return Data.hourStr(t.hour as Number) + ":" + (t.min as Number).format("%02d");
    }

    function drawActive(dc as Dc) as Void {
        for (var i = 0; i < 48; i++) {
            var deg = 3.75 + 7.5 * i;
            var v = mBuckets[i];
            if (v == null) {
                tick(dc, deg, 154, 3, 0x2A2A2A, 4.5);
            } else {
                var t = level(v);
                tick(dc, deg, 154, 6 + 24 * t, gradient(t), 4.5);
            }
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Gfx.sx(195), Gfx.sy(49), Gfx.s(2.5));

        // Centered column: 14.4 + 87.4 + 26.4 + 8 + 15.6 = 151.8 tall, top 119.1.
        var temp = Data.temperature();
        var date = Data.dateStr() + " · " + (temp != null ? temp + "°" : "--°");
        Gfx.text(dc, 195, 126.3, fDate, date, 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);

        Gfx.text(dc, 195, 177.2, fTime, timeStr(), 0xFFFFFF, Graphics.TEXT_JUSTIFY_CENTER);

        // "62  BPM · 24H 51-128", baseline aligned.
        var big = fHr;
        var small = fRange;
        var hr = Data.fmt(Data.heartRate());
        var rng = "BPM · 24H " + (mMin != null && mMax != null ? mMin + "–" + mMax : "--");
        var w1 = Gfx.width(dc, hr, big);
        var w2 = Gfx.width(dc, rng, small);
        var x = 195 - (w1 + 6 + w2) / 2;
        Gfx.text(dc, x, 234.1, big, hr, Gfx.accent(0x4DD0E1), Graphics.TEXT_JUSTIFY_LEFT);
        Gfx.text(dc, x + w1 + 6, 238.4, small, rng, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);

        // Stats row: value (light) + unit (grey), gap 12, 13px.
        var f = fStats;
        var vals = [Data.thousands(Data.steps()), Data.fmt(Data.bodyBattery()), Data.fmt(Data.stress()), Data.battery().toString()];
        var units = [" st", " bb", " str", "%"];
        var total = 36.0;
        for (var i = 0; i < 4; i++) {
            total += Gfx.width(dc, vals[i] as String, f) + Gfx.width(dc, units[i] as String, f);
        }
        x = 195 - total / 2;
        for (var i = 0; i < 4; i++) {
            Gfx.text(dc, x, 263.1, f, vals[i] as String, 0xD0D0D0, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, vals[i] as String, f);
            Gfx.text(dc, x, 263.1, f, units[i] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, units[i] as String, f) + 12;
        }
    }

    function drawAod(dc as Dc) as Void {
        for (var i = 0; i < 48; i++) {
            var v = mBuckets[i];
            var len = v == null ? 2 : 3.2 + 12.6 * level(v);
            tick(dc, 3.75 + 7.5 * i, 166, len, 0x4A4A4A, 2);
        }
        // Column: 14.4 + 4 + 87.4 + 4 + 15.6 = 125.4 tall, top 132.3.
        Gfx.text(dc, 195, 139.5, fDateAod, Data.dateStr(), 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, 195, 194.6, fTime, timeStr(), 0xA8A8A8, Graphics.TEXT_JUSTIFY_CENTER);
        var s = "HR " + Data.fmt(Data.heartRate()) + " · BB " + Data.fmt(Data.bodyBattery());
        Gfx.text(dc, 195, 249.9, fAod, s, 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
