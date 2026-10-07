import Toybox.Lang;
import Toybox.Math;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Shared data access. Every getter returns null when the source is missing;
// use Data.fmt() / "--" for display. Copy this file unchanged into new faces.
module Data {

    var _loc as Position.Location or Null = null;

    function heartRate() as Number or Null {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var s = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (s != null && s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return s.heartRate;
            }
        }
        return null;
    }

    // Heart rate samples, oldest first, invalid samples skipped. Max `count` values.
    function hrHistory(count as Number) as Array<Number> {
        var out = [] as Array<Number>;
        if (!(ActivityMonitor has :getHeartRateHistory)) {
            return out;
        }
        var it = ActivityMonitor.getHeartRateHistory(null, true);
        var s = it.next();
        while (s != null && out.size() < count) {
            if (s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                out.add(s.heartRate as Number);
            }
            s = it.next();
        }
        return out.reverse();
    }

    function _am() as ActivityMonitor.Info {
        return ActivityMonitor.getInfo();
    }

    function steps() as Number or Null { return _am().steps; }
    function stepGoal() as Number or Null { return _am().stepGoal; }
    function calories() as Number or Null { return _am().calories; }

    // Distance today in km (or miles on statute devices).
    function distance() as Float or Null {
        var cm = _am().distance;
        if (cm == null) { return null; }
        var km = cm / 100000.0;
        if (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) {
            return km * 0.621371;
        }
        return km;
    }

    function distanceUnit() as String {
        return System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE ? "MI" : "KM";
    }

    function activeMinutesWeek() as Number or Null {
        var a = _am().activeMinutesWeek;
        return a != null ? a.total : null;
    }

    function activeMinutesWeekGoal() as Number or Null {
        return _am().activeMinutesWeekGoal;
    }

    function _latest(iter) as Number or Null {
        if (iter == null) { return null; }
        var s = iter.next();
        while (s != null) {
            if (s.data != null) { return (s.data as Numeric).toNumber(); }
            s = iter.next();
        }
        return null;
    }

    function bodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            return _latest(SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}));
        }
        return null;
    }

    function stress() as Number or Null {
        var am = _am();
        if ((am has :stressScore) && am.stressScore != null) {
            return am.stressScore;
        }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            return _latest(SensorHistory.getStressHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}));
        }
        return null;
    }

    function spo2() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getOxygenSaturationHistory)) {
            return _latest(SensorHistory.getOxygenSaturationHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}));
        }
        return null;
    }

    function battery() as Number {
        return System.getSystemStats().battery.toNumber();
    }

    function notifications() as Number or Null {
        return System.getDeviceSettings().notificationCount;
    }

    function _conditions() as Weather.CurrentConditions or Null {
        if (Toybox has :Weather) {
            return Weather.getCurrentConditions();
        }
        return null;
    }

    // Temperature in the user's unit (C or F), rounded.
    function temperature() as Number or Null {
        var c = _conditions();
        if (c == null || c.temperature == null) { return null; }
        var t = c.temperature as Numeric;
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            t = t * 9.0 / 5.0 + 32;
        }
        return Math.round(t).toNumber();
    }

    // Weather.CONDITION_* or null.
    function condition() as Number or Null {
        var c = _conditions();
        return c != null ? c.condition : null;
    }

    function _location() as Position.Location or Null {
        var c = _conditions();
        if (c != null && c.observationLocationPosition != null) {
            _loc = c.observationLocationPosition;
        } else {
            var info = Activity.getActivityInfo();
            if (info != null && info.currentLocation != null) {
                _loc = info.currentLocation;
            }
        }
        return _loc;
    }

    function sunrise() as Time.Moment or Null {
        var loc = _location();
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunrise)) { return null; }
        return Weather.getSunrise(loc, Time.now());
    }

    function sunset() as Time.Moment or Null {
        var loc = _location();
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunset)) { return null; }
        return Weather.getSunset(loc, Time.now());
    }

    // ---- formatting ----

    function fmt(v) as String {
        return v == null ? "--" : v.toString();
    }

    // 7412 -> "7,412"
    function thousands(v as Number or Null) as String {
        if (v == null) { return "--"; }
        var n = v as Number;
        if (n < 1000) { return n.toString(); }
        return (n / 1000).toString() + "," + (n % 1000).format("%03d");
    }

    function is24() as Boolean {
        return System.getDeviceSettings().is24Hour;
    }

    function hourStr(hour as Number) as String {
        if (is24()) { return hour.format("%02d"); }
        var h = hour % 12;
        return (h == 0 ? 12 : h).toString();
    }

    function clock() as Gregorian.Info {
        return Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    }

    // "MON 05 OCT"
    function dateStr() as String {
        var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return (d.day_of_week as String).toUpper() + " " + d.day.format("%02d") + " " + (d.month as String).toUpper();
    }

    // Full English weekday, upper case ("MONDAY"). Gregorian FORMAT_LONG returns
    // the abbreviation on some devices (vivoactive6 shows "WED"), so map it ourselves.
    function weekday() as String {
        var dow = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day_of_week as Number;
        return ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"][dow - 1];
    }

    // Moment -> "5:58" / "17:52" (respects 12/24h).
    function timeOf(m as Time.Moment or Null) as String {
        if (m == null) { return "--:--"; }
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        var h = i.hour as Number;
        if (!is24()) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.toString() + ":" + (i.min as Number).format("%02d");
    }
}
