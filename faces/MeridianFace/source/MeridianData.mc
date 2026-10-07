import Toybox.Lang;
import Toybox.Math;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;
import Toybox.Complications;

// Data options for AE · Meridian (one enum shared by all 8 slots; values match the
// listEntry values in resources/properties/properties.xml).
module MD {

    enum {
        NONE, STEPS, STEPS_PCT, DISTANCE, CALORIES, INTENSITY, HR, RHR, BODY_BATT, STRESS,
        SPO2, RESP, BATT, BATT_DAYS, TEMP, WEATHER, HILO, PRECIP, HUMIDITY, WIND, UV,
        SUNRISE, SUNSET, NEXT_SUN, NOTIF, ALARMS, PHONE, DATE, WEEK, ALTITUDE, RECOVERY,
        TRAINING, VO2, SLEEP, CALENDAR, FLOORS, PRESSURE
    }

    // Icons (MeridianIcons.mc).
    enum {
        I_NONE, I_FOOT, I_TARGET, I_PIN, I_FLAME, I_STOPWATCH, I_HEART, I_BODY, I_STRESS, I_O2,
        I_LUNGS, I_BATTERY, I_BOLT, I_THERMO, I_SUN, I_PARTLY, I_CLOUD, I_RAIN, I_SNOW, I_STORM,
        I_UMBRELLA, I_DROP, I_WIND, I_SUNRISE, I_SUNSET, I_BELL, I_ALARM, I_PHONE, I_CALENDAR,
        I_MOUNTAIN, I_RECOVERY, I_TREND, I_GAUGE, I_MOON, I_STAIRS, I_BARO
    }

    const RED = 0xFF3B4E;
    const ORANGE = 0xF5A33A;
    const YELLOW = 0xFFC21A;
    const GREEN = 0x5BE15B;
    const BLUE = 0x4DA3FF;
    const SKY = 0x7DD3FC;

    // Default (icon) color per data option, indexed by option.
    const COLORS = [0x8A8A8A, 0xF0399F, 0xF0399F, 0x4DA3FF, 0xFF7A3D, 0xF5A33A, 0xEF3348, 0xFF6B7A,
        0x4DC3FF, 0xF5A33A, 0x4DA3FF, 0x7DD3FC, 0x5BE15B, 0x5BE15B, 0xF5A33A, 0xF5A33A, 0xF5A33A,
        0x4DA3FF, 0x4DA3FF, 0x7DD3FC, 0xFFC21A, 0xF7B52C, 0xFF7A3D, 0xF7B52C, 0xF7E03A, 0xFFC21A,
        0x4DA3FF, 0x4A90E2, 0xC8C8C8, 0xB9A6FF, 0xFFE11A, 0x5BE15B, 0xFF7A3D, 0xB9A6FF, 0xC8C8C8,
        0x6EE7B7, 0xB9A6FF] as Array<Number>;

    // Native editor (WatchFaceConfig) / complication-backed slots.
    const GENERIC = -2;   // slot shows an unmapped complication (infoComp)

    // Complications type (0..42) -> our data option, or GENERIC when we have no own rendering.
    const FROM_COMP = [GENERIC, BATT_DAYS, STEPS, CALORIES, FLOORS, INTENSITY, DATE, DATE, WEATHER,
        GENERIC, GENERIC, GENERIC, CALENDAR, SUNRISE, SUNSET, ALTITUDE, PRESSURE, NOTIF, HR,
        GENERIC, GENERIC, RECOVERY, STRESS, BODY_BATT, VO2, GENERIC, TRAINING, GENERIC, GENERIC,
        GENERIC, GENERIC, GENERIC, GENERIC, GENERIC, GENERIC, SPO2, RESP, GENERIC, TEMP, HILO,
        GENERIC, GENERIC, SLEEP] as Array<Number>;

    // Data option -> Complications type that opens the related Garmin app on long-press (0 = none).
    const TO_COMP = [0, 2, 2, 0, 3, 5, 18, 18, 23, 22, 35, 36, 1, 1, 38, 8, 39, 8, 8, 8, 8,
        13, 14, 13, 17, 0, 0, 7, 0, 15, 21, 26, 24, 42, 12, 4, 16] as Array<Number>;

    function fromComp(type as Number) as Number {
        if (type < 0 || type >= FROM_COMP.size()) { return GENERIC; }
        var o = FROM_COMP[type];
        if (o == BATT_DAYS && !(System.getSystemStats() has :batteryInDays)) { return BATT; }
        return o;
    }

    // Default icon/arc color of an option (GENERIC: light grey).
    function color(opt as Number) as Number {
        return (opt >= 0 && opt < COLORS.size()) ? COLORS[opt] : 0xC8C8C8;
    }

    // Per-frame caches.
    var _cond = null;
    var _condRead as Boolean = false;

    // Call once per onUpdate before info().
    function begin() as Void {
        _cond = null;
        _condRead = false;
    }

    function cond() as Weather.CurrentConditions or Null {
        if (!_condRead) {
            _condRead = true;
            if (Toybox has :Weather) {
                _cond = Weather.getCurrentConditions();
            }
        }
        return _cond;
    }

    // Native complication value, or null (no Complications API, not found, no value).
    function comp(type as Number) {
        if (!(Toybox has :Complications)) { return null; }
        try {
            var c = Complications.getComplication(new Complications.Id(type as Complications.Type));
            return c != null ? c.value : null;
        } catch (e) {
            return null;
        }
    }

    function _num(v) as Number or Null {
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Double || v instanceof Long) { return v.toNumber(); }
        return null;
    }

    function _clamp(p as Float) as Float {
        return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
    }

    function _ratio(v as Numeric or Null, lo as Numeric, hi as Numeric) as Float or Null {
        if (v == null) { return null; }
        return _clamp((v - lo).toFloat() / (hi - lo));
    }

    function statute() as Boolean {
        return System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
    }

    // "12k", "7,412"
    function compact(v as Number or Null) as String {
        if (v == null) { return "--"; }
        if (v >= 10000) { return (v / 1000).toString() + "k"; }
        return Data.thousands(v);
    }

    function batteryColor(v as Number or Null) as Number or Null {
        if (v == null) { return null; }
        return v < 20 ? RED : (v < 50 ? ORANGE : GREEN);
    }

    function tempColor(c as Numeric or Null) as Number or Null {
        if (c == null) { return null; }
        if (c < 5) { return BLUE; }
        if (c < 15) { return SKY; }
        if (c < 24) { return YELLOW; }
        if (c < 32) { return ORANGE; }
        return RED;
    }

    function tempC() as Float or Null {
        var c = cond();
        if (c != null && c.temperature != null) { return (c.temperature as Numeric).toFloat(); }
        var v = comp(38); // COMPLICATION_TYPE_CURRENT_TEMPERATURE (Celsius)
        return (v instanceof Number || v instanceof Float) ? v.toFloat() : null;
    }

    function tempStr(c as Numeric or Null) as String {
        if (c == null) { return "--"; }
        var t = c.toFloat();
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            t = t * 9.0 / 5.0 + 32;
        }
        return Math.round(t).toNumber().toString() + "°";
    }

    function hrColor(hr as Number or Null) as Number or Null {
        if (hr == null) { return null; }
        var z = null;
        if (Toybox has :UserProfile) {
            try {
                z = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
            } catch (e) {
                z = null;
            }
        }
        if (z == null || z.size() < 6) { return null; }
        if (hr < z[0]) { return null; }
        if (hr <= z[1]) { return 0x9FB4C7; }
        if (hr <= z[2]) { return BLUE; }
        if (hr <= z[3]) { return GREEN; }
        if (hr <= z[4]) { return ORANGE; }
        return RED;
    }

    function weatherIcon(c as Number or Null) as Number {
        if (c == null) { return I_PARTLY; }
        if (c == 0 || c == 23 || c == 40) { return I_SUN; }
        if (c == 1 || c == 22 || c == 52 || c == 9 || c == 39) { return I_PARTLY; }
        if (c == 6 || c == 12 || c == 28 || c == 32 || c == 41 || c == 42) { return I_STORM; }
        if (c == 4 || c == 7 || c == 10 || (c >= 16 && c <= 19) || c == 21 || c == 34 || (c >= 43 && c <= 44)
                || (c >= 46 && c <= 48) || c == 50 || c == 51) { return I_SNOW; }
        if (c == 3 || c == 11 || c == 13 || c == 14 || c == 15 || (c >= 24 && c <= 27) || c == 31
                || c == 45 || c == 49) { return I_RAIN; }
        return I_CLOUD;
    }

    // Seconds since local midnight -> "7:24"
    function secStr(s as Number) as String {
        var h = s / 3600;
        if (!Data.is24()) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.toString() + ":" + ((s % 3600) / 60).format("%02d");
    }

    function sunTime(rise as Boolean) as String {
        var m = rise ? Data.sunrise() : Data.sunset();
        if (m != null) { return Data.timeOf(m); }
        var v = _num(comp(rise ? 13 : 14));
        return v != null ? secStr(v) : "--:--";
    }

    // ISO-8601 week number.
    function isoWeek() as Number {
        var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var y = d.year as Number;
        var cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        var leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
        var doy = cum[(d.month as Number) - 1] + (d.day as Number) + ((leap && (d.month as Number) > 2) ? 1 : 0);
        var iso = ((d.day_of_week as Number) + 5) % 7 + 1; // Mon=1..Sun=7
        var w = (doy - iso + 10) / 7;
        if (w < 1) { return _weeksIn(y - 1); }
        if (w > _weeksIn(y)) { return 1; }
        return w;
    }

    function _p(y as Number) as Number {
        return (y + y / 4 - y / 100 + y / 400) % 7;
    }

    function _weeksIn(y as Number) as Number {
        return (_p(y) == 4 || _p(y - 1) == 3) ? 53 : 52;
    }

    // An unmapped complication: its value (+ unit when short), its short label in place of the
    // icon (if 4 chars or less, else a generic icon), no progress. Same shape as info().
    function infoComp(id) as Array {
        var txt = "--";
        var label = null;
        if ((Toybox has :Complications) && id != null) {
            try {
                var c = Complications.getComplication(id as Complications.Id);
                var v = c.value;
                if (v instanceof String) {
                    txt = v;
                } else if (v instanceof Float || v instanceof Double) {
                    var f = v.toFloat();
                    txt = (f < 100 && f > -100) ? f.format("%.1f") : Math.round(f).toNumber().toString();
                } else if (v != null) {
                    txt = v.toString();
                }
                var u = c.unit instanceof String ? c.unit as String : "";
                if ((v instanceof Number || v instanceof Long) && u.equals("s") && v >= 60) {
                    var n = v.toNumber();   // a duration (race predictors): 1:23:45 / 23:45
                    txt = n >= 3600 ? (n / 3600) + ":" + (n % 3600 / 60).format("%02d") + ":" + (n % 60).format("%02d")
                                    : (n / 60) + ":" + (n % 60).format("%02d");
                } else if (v != null && !(v instanceof String) && u.length() <= 2) {
                    txt += u;
                }
                var l = c.shortLabel;
                if (l != null && l.length() > 0 && l.length() <= 4) { label = l.toUpper(); }
            } catch (e) {
            }
        }
        return [txt, null, null, label == null ? I_GAUGE : I_NONE, label];
    }

    // Data for one option:
    //   [text, progress (Float 0..1 or null = no natural max), dynamic color (or null),
    //    icon, label text (or null; drawn instead of the icon)]
    function info(opt as Number) as Array {
        var txt = "--";
        var prog = null;
        var col = null;
        var icon = I_NONE;
        var label = null;
        var am = ActivityMonitor.getInfo();
        if (opt == STEPS || opt == STEPS_PCT) {
            icon = opt == STEPS ? I_FOOT : I_TARGET;
            var s = am.steps;
            var g = am.stepGoal;
            if (s != null && g != null && g > 0) { prog = _clamp(s.toFloat() / g); }
            if (opt == STEPS) {
                txt = compact(s);
            } else if (prog != null) {
                txt = (s * 100 / g).toString() + "%";
            }
        } else if (opt == DISTANCE) {
            icon = I_PIN;
            var d = Data.distance();
            if (d != null) { txt = d.format(d < 10 ? "%.1f" : "%.0f") + (statute() ? "mi" : "km"); }
        } else if (opt == CALORIES) {
            icon = I_FLAME;
            txt = compact(am.calories);
        } else if (opt == INTENSITY) {
            icon = I_STOPWATCH;
            var v = Data.activeMinutesWeek();
            if (v == null) { v = _num(comp(5)); }
            txt = Data.fmt(v);
            var g = Data.activeMinutesWeekGoal();
            if (v != null && g != null && g > 0) { prog = _clamp(v.toFloat() / g); }
        } else if (opt == HR) {
            icon = I_HEART;
            var v = Data.heartRate();
            if (v == null) { v = _num(comp(18)); }
            txt = Data.fmt(v);
            col = hrColor(v);
            if (v != null) { prog = _clamp((v as Number).toFloat() / 190.0); }
        } else if (opt == RHR) {
            icon = I_HEART;
            var v = null;
            if (Toybox has :UserProfile) {
                var p = UserProfile.getProfile();
                if (p != null && (p has :restingHeartRate)) { v = p.restingHeartRate; }
            }
            txt = Data.fmt(v);
            if (v != null) { prog = _clamp((v as Number).toFloat() / 100.0); }
        } else if (opt == BODY_BATT) {
            icon = I_BODY;
            var v = Data.bodyBattery();
            if (v == null) { v = _num(comp(23)); }
            txt = Data.fmt(v);
            prog = _ratio(v, 0, 100);
            col = batteryColor(v);
        } else if (opt == STRESS) {
            icon = I_STRESS;
            var v = Data.stress();
            if (v == null) { v = _num(comp(22)); }
            txt = Data.fmt(v);
            prog = _ratio(v, 0, 100);
            if (v != null) { col = v < 26 ? GREEN : (v < 51 ? YELLOW : (v < 76 ? ORANGE : RED)); }
        } else if (opt == SPO2) {
            icon = I_O2;
            var v = Data.spo2();
            if (v == null) { v = _num(comp(35)); }
            if (v != null) {
                txt = v.toString() + "%";
                prog = _ratio(v, 80, 100);
                col = v < 90 ? RED : (v < 95 ? ORANGE : null);
            }
        } else if (opt == RESP) {
            icon = I_LUNGS;
            var v = (am has :respirationRate) ? am.respirationRate : null;
            if (v == null) { v = _num(comp(36)); }
            txt = Data.fmt(v);
        } else if (opt == BATT || opt == BATT_DAYS) {
            icon = opt == BATT ? I_BATTERY : I_BOLT;
            var b = Data.battery();
            prog = _ratio(b, 0, 100);
            col = batteryColor(b);
            if (opt == BATT) {
                txt = b.toString() + "%";
            } else {
                var st = System.getSystemStats();
                if (st has :batteryInDays) {
                    var d = st.batteryInDays;
                    if (d != null) {
                        txt = d >= 1 ? d.toNumber().toString() + "d" : (d * 24).toNumber().toString() + "h";
                    }
                }
            }
        } else if (opt == TEMP || opt == WEATHER) {
            var t = tempC();
            txt = tempStr(t);
            prog = _ratio(t, -10, 40);
            col = tempColor(t);
            if (opt == TEMP) {
                icon = I_THERMO;
            } else {
                var c = cond();
                var cn = c != null ? c.condition : _num(comp(8));
                icon = weatherIcon(cn);
            }
        } else if (opt == HILO) {
            icon = I_THERMO;
            var c = cond();
            if (c != null && c.highTemperature != null && c.lowTemperature != null) {
                txt = tempStr(c.highTemperature) + "/" + tempStr(c.lowTemperature);
            } else {
                var v = comp(39);
                if (v instanceof String) { txt = v; }
            }
        } else if (opt == PRECIP) {
            icon = I_UMBRELLA;
            var c = cond();
            if (c != null && c.precipitationChance != null) {
                txt = c.precipitationChance.toString() + "%";
                prog = _ratio(c.precipitationChance, 0, 100);
            }
        } else if (opt == HUMIDITY) {
            icon = I_DROP;
            var c = cond();
            if (c != null && c.relativeHumidity != null) {
                txt = c.relativeHumidity.toString() + "%";
                prog = _ratio(c.relativeHumidity, 0, 100);
            }
        } else if (opt == WIND) {
            icon = I_WIND;
            var c = cond();
            if (c != null && c.windSpeed != null) {
                var ms = c.windSpeed as Float;
                txt = statute() ? Math.round(ms * 2.23694).toNumber().toString() + "mph"
                                : Math.round(ms * 3.6).toNumber().toString() + "kmh";
                prog = _ratio(ms, 0, 20);
            }
        } else if (opt == UV) {
            label = "UV";
            var c = cond();
            if (c != null && (c has :uvIndex) && c.uvIndex != null) {
                var u = c.uvIndex as Float;
                txt = Math.round(u).toNumber().toString();
                prog = _ratio(u, 0, 11);
                col = u < 3 ? GREEN : (u < 6 ? YELLOW : (u < 7 ? ORANGE : RED));
            }
        } else if (opt == SUNRISE) {
            icon = I_SUNRISE;
            txt = sunTime(true);
        } else if (opt == SUNSET) {
            icon = I_SUNSET;
            txt = sunTime(false);
        } else if (opt == NEXT_SUN) {
            var r = Data.sunrise();
            var s = Data.sunset();
            var now = Time.now().value();
            if (r != null && s != null && now >= r.value() && now < s.value()) {
                icon = I_SUNSET;
                txt = Data.timeOf(s);
            } else {
                icon = I_SUNRISE;
                txt = sunTime(true);
            }
        } else if (opt == NOTIF) {
            icon = I_BELL;
            txt = Data.fmt(Data.notifications());
        } else if (opt == ALARMS) {
            icon = I_ALARM;
            txt = System.getDeviceSettings().alarmCount.toString();
        } else if (opt == PHONE) {
            icon = I_PHONE;
            var on = System.getDeviceSettings().phoneConnected;
            txt = on ? "ON" : "OFF";
            prog = on ? 1.0 : 0.0;
            col = on ? BLUE : 0x8A8A8A;
        } else if (opt == DATE) {
            var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            label = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][(d.day_of_week as Number) - 1];
            txt = (d.day as Number).toString();
        } else if (opt == WEEK) {
            label = "WK";
            var w = isoWeek();
            txt = w.toString();
            prog = _ratio(w, 0, 52);
        } else if (opt == ALTITUDE) {
            icon = I_MOUNTAIN;
            var a = null;
            var ai = Activity.getActivityInfo();
            if (ai != null && ai.altitude != null) { a = ai.altitude; }
            if (a == null) {
                var v = comp(15);
                if (v instanceof Number || v instanceof Float) { a = v; }
            }
            if (a != null) {
                if (System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE) { a = a * 3.28084; }
                txt = Math.round(a).toNumber().toString();
            }
        } else if (opt == RECOVERY) {
            icon = I_RECOVERY;
            var v = _num(comp(21));
            if (v != null) {
                var h = (v + 59) / 60;
                txt = h.toString() + "h";
                prog = _ratio(h, 0, 72);
                col = h < 12 ? GREEN : (h < 36 ? 0xFFE11A : (h < 60 ? ORANGE : RED));
            }
        } else if (opt == TRAINING) {
            icon = I_TREND;
            var v = comp(26);
            if (v instanceof String) { txt = v.toUpper(); }
        } else if (opt == VO2) {
            icon = I_GAUGE;
            var v = _num(comp(24));
            txt = Data.fmt(v);
            prog = _ratio(v, 20, 70);
        } else if (opt == SLEEP) {
            icon = I_MOON;
            var v = _num(comp(42));
            txt = Data.fmt(v);
            prog = _ratio(v, 0, 100);
            if (v != null) { col = v < 60 ? ORANGE : (v < 80 ? YELLOW : null); }
        } else if (opt == CALENDAR) {
            icon = I_CALENDAR;
            var v = comp(12);
            if (v instanceof String) { txt = v; }
        } else if (opt == FLOORS) {
            icon = I_STAIRS;
            var v = (am has :floorsClimbed) ? am.floorsClimbed : null;
            if (v == null) { v = _num(comp(4)); }
            txt = Data.fmt(v);
            var g = (am has :floorsClimbedGoal) ? am.floorsClimbedGoal : null;
            if (v != null && g != null && g > 0) { prog = _clamp(v.toFloat() / g); }
        } else if (opt == PRESSURE) {
            icon = I_BARO;
            var v = comp(16);
            var pa = (v instanceof Number || v instanceof Float) ? v.toFloat() : null;
            if (pa == null) {
                var ai = Activity.getActivityInfo();
                if (ai != null && (ai has :meanSeaLevelPressure) && ai.meanSeaLevelPressure != null) {
                    pa = ai.meanSeaLevelPressure.toFloat();
                }
            }
            if (pa == null) {
                var c = cond();
                if (c != null && (c has :pressure) && c.pressure != null) { pa = c.pressure.toFloat(); }
            }
            if (pa != null) { txt = Math.round(pa / 100.0).toNumber().toString(); }
        }
        return [txt, prog, col, icon, label];
    }
}
