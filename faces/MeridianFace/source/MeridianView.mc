import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Face AE · Meridian — mockups/Meridian.dc.html (active), mockups/MeridianAOD.dc.html (always-on).
// Big stacked hour/minute, 4 data circles (N/W/E/S, clipped by the screen edge) and 4 rim arc
// gauges; every data field and color is configurable.
class MeridianView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    // ---- themes (Black, Navy, Charcoal, Cream, White); from the mockup's renderVals ----
    const BG = [0x0B0B0B, 0x1B2A44, 0x20262E, 0xF4EEE3, 0xFFFFFF] as Array<Number>;
    const TEXT = [0xFFFFFF, 0xE8E8EA, 0xFFFFFF, 0x2B2B2B, 0x1B1B1B] as Array<Number>;
    const OUTLINE = [0x3C3C3C, 0x8E8E93, 0x4A5562, 0xC9B79A, 0xBDBDBD] as Array<Number>;
    const TRACK = [0x4A4A4A, 0x8E8E93, 0x55606C, 0x3E8EA3, 0xD6D6D6] as Array<Number>;
    const WEEKDAY = [0x4A90E2, 0xF2B9A6, 0x5FD3F3, 0xB3412E, 0x4A90E2] as Array<Number>;
    const HOUR = [0xFFFFFF, 0xC9E86B, 0x9BF0B0, 0x1F4E5F, 0x1F4E5F] as Array<Number>;
    const HOUR_END = [0xBDBDBD, 0x9EE6C8, 0x5FD3F3, 0x1F4E5F, 0x1F4E5F] as Array<Number>;
    const MINUTE = [0xFFFFFF, 0xA9D6FF, 0x5FD3F3, 0xB3412E, 0xB3412E] as Array<Number>;
    // Theme "Auto" colors for arcs and circle icons (Black and White use the dynamic data colors).
    const NAVY_ARCS = [0x7FB2E8, 0xD7DE8A, 0xE3A04E, 0xC8443A] as Array<Number>;
    const CREAM_ACCENT = 0x3E8EA3;
    const CREAM_ICON = 0xB3412E;
    const CHARCOAL_ACCENT = 0xC6F432;

    // Gradients (setting values -2..-9): top color, bottom color.
    const GRAD = [0xFFFFFF, 0xB4B4B4, 0xC6F432, 0x2DD4BF, 0xC6F432, 0xCFE8C8, 0xC6F432, 0xA9D3FF,
                  0xFF3DA5, 0xFFA62B, 0xA9D3FF, 0xB9B4F5, 0xFFC21A, 0xFF3B4E, 0x2DD4BF, 0x4DA3FF] as Array<Number>;

    const AUTO = -1;
    const DYNAMIC = -10;

    // ---- geometry (390 design units, from the mockup) ----
    const CX = 195;
    const CY = 195;
    const HOUR_Y = 146;          // cap centers; the digits touch
    const MIN_Y = 244;
    const DIGIT_H = 97;          // cap height of the time font
    const CIRCLE_R = 51;
    // Circles: top, left, right, bottom (the screen edge clips their outer part).
    // Symmetric: every circle is 159 from the center.
    const SLOT_X = [195, 36, 354, 195] as Array<Number>;
    const SLOT_Y = [36, 195, 195, 354] as Array<Number>;
    const ICON_X = [195, 39, 351, 195] as Array<Number>;
    const ICON_Y = [17, 177, 177, 330] as Array<Number>;
    const ICON_SZ = [34, 36, 36, 36] as Array<Number>;
    const VALUE_X = [195, 39, 351, 195] as Array<Number>;
    const VALUE_Y = [60, 217, 217, 373] as Array<Number>;
    const ARC_R = 175;
    const ICON_R = 173;
    const ICON_R0 = 169;         // icon radius when the fill is empty
    const ARC_W = 8;
    const TRACK_W = 3.5;
    // Per arc (TL, TR, BL, BR): track from/to (clock degrees, from < to), fill base (the end the
    // fill grows from), the other end, value text angle and radius.
    // All four arcs are the same 48-degree shape, mirrored; fills grow upward along the rim.
    // Each arc spans 48 degrees centered on its diagonal: a 21-degree gap to both neighbouring circles.
    const ARC_A = [291, 21, 201, 111] as Array<Number>;
    const ARC_B = [339, 69, 249, 159] as Array<Number>;
    // Fills start next to the side circle (left/right) and grow toward the top/bottom circle,
    // mirrored in all four corners.
    const ARC_BASE = [291, 69, 249, 111] as Array<Number>;
    const ARC_END = [339, 21, 201, 159] as Array<Number>;
    const ARC_TEXT = [315, 45, 225, 135] as Array<Numeric>;
    const ARC_TEXT_R = [141, 141, 141, 141] as Array<Number>;

    // ---- settings ----
    var mSlots as Array<Number> = [34, 21, 27, 24] as Array<Number>;
    var mArcs as Array<Number> = [1, 13, 15, 6] as Array<Number>;
    var mArcColors as Array<Number> = [-1, -1, -1, -1] as Array<Number>;
    var mTheme as Number = 0;
    var mStyle as Number = 0;
    var mFrame as Number = 0;

    var mTimeFmt as Number = 0;
    var mLead as Boolean = true;
    var mHourC as Number = -1;
    var mMinC as Number = -1;
    var mWeekdayC as Number = -1;
    var mTextC as Number = -1;
    var mIconC as Number = -1;
    var mOutlineC as Number = -1;
    var mTrackC as Number = -1;

    // ---- native watch-face editor (WatchFaceConfig, MeridianNative.mc) ----
    var mEdit as Boolean = false;          // started by the system's watch-face editor
    var mHide as Number = -1;              // slot (0..7) hidden while its complication is edited
    var mCfg = null;                       // settings being edited (WatchFaceConfig.Settings)
    // Complications.Id per slot (0..3 circles, 4..7 arcs) chosen in the native editor, else null.
    var mIds as Array = [null, null, null, null, null, null, null, null] as Array;

    // Fonts. Only the selected time style is loaded (solid while awake, outlined while asleep).
    var fTime as FontResource or Null = null;
    var mFontKey as Number = -1;
    var fValue as FontResource;
    var fValueSm as FontResource;
    var fLabel as FontResource;
    var fAodInfo as FontResource;
    var mVec as Graphics.FontType or Null = null;  // vector font for the radial arc values
    var mVecSize as Number = 0;

    function initialize(edit as Boolean) {
        WatchFace.initialize();
        mEdit = edit;
        fValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        fValueSm = WatchUi.loadResource(Rez.Fonts.ValueSm) as FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        fAodInfo = WatchUi.loadResource(Rez.Fonts.AodInfo) as FontResource;
        Icons.font = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
        Icons.fontSm = WatchUi.loadResource(Rez.Fonts.IconsSm) as FontResource;
        loadSettings();
    }

    function _prop(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        return v instanceof Number ? v : def;
    }

    // A data-option setting, falling back to the default when out of range.
    function _opt(key as String, def as Number) as Number {
        var v = _prop(key, def);
        return (v < MD.NONE || v > MD.PRESSURE) ? def : v;
    }

    function _bool(key as String, def as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        return v instanceof Boolean ? v : def;
    }

    function loadSettings() as Void {
        mSlots = [_opt("SlotTop", 34), _opt("SlotLeft", 21), _opt("SlotRight", 27), _opt("SlotBottom", 24)];
        mArcs = [_opt("ArcTL", 1), _opt("ArcTR", 13), _opt("ArcBL", 15), _opt("ArcBR", 6)];
        mArcColors = [_prop("ArcColorTL", -1), _prop("ArcColorTR", -1), _prop("ArcColorBL", -1), _prop("ArcColorBR", -1)];
        mTheme = _prop("Theme", 0);
        if (mTheme < 0 || mTheme > 4) { mTheme = 0; }
        mStyle = _prop("FontStyle", 0);
        if (mStyle < 0 || mStyle > 3) { mStyle = 0; }
        mFrame = _prop("Frame", 0);
        if (mFrame < 0 || mFrame > 2) { mFrame = 0; }
        mTimeFmt = _prop("TimeFormat", 0);
        mLead = _bool("LeadingZero", true);
        mHourC = _prop("HourColor", -1);
        mMinC = _prop("MinuteColor", -1);
        mWeekdayC = _prop("WeekdayColor", -1);
        mTextC = _prop("TextColor", -1);
        mIconC = _prop("IconColor", -1);
        mOutlineC = _prop("OutlineColor", -1);
        mTrackC = _prop("TrackColor", -1);
        mIds = [null, null, null, null, null, null, null, null] as Array;
        Native.apply(self, mCfg);
        loadFont();
    }

    // Load exactly one time font: the selected style, outlined when sleeping.
    function loadFont() as Void {
        var key = mStyle + (mSleep ? 4 : 0);
        if (key == mFontKey && fTime != null) { return; }
        fTime = null;  // release the previous font before loading the next
        var ids = [Rez.Fonts.TimeRound, Rez.Fonts.TimeSquare, Rez.Fonts.TimeSerif, Rez.Fonts.TimeClassic,
                   Rez.Fonts.AodRound, Rez.Fonts.AodSquare, Rez.Fonts.AodSerif, Rez.Fonts.AodClassic];
        fTime = WatchUi.loadResource(ids[key]) as FontResource;
        mFontKey = key;
    }

    function onEnterSleep() as Void {
        mSleep = true;
        loadFont();
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mSleep = false;
        loadFont();
        WatchUi.requestUpdate();
    }

    function _pick(v as Number, auto as Number) as Number {
        return v == AUTO ? auto : v;
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

    // ---------------------------------------------------------------- active

    function drawActive(dc as Dc) as Void {
        var bg = BG[mTheme];
        dc.setColor(bg, bg);
        dc.clear();
        MD.begin();
        var text = _pick(mTextC, TEXT[mTheme]);
        var outline = _pick(mOutlineC, OUTLINE[mTheme]);
        var track = _pick(mTrackC, TRACK[mTheme]);

        for (var i = 0; i < 4; i++) {
            if (mHide != i + 4) { drawArc(dc, i, bg, text, track); }
        }
        for (var i = 0; i < 4; i++) {
            if (mHide != i) { drawSlot(dc, i, bg, text, outline); }
        }
        drawTime(dc);
    }

    // Slot k alone (0..3 circles, 4..7 arcs), for the native editor's highlight drawable.
    // The dc shares the screen's origin, so the normal drawing code is reused as is.
    function drawOne(dc as Dc, k as Number) as Void {
        Gfx.k = Native.scale();
        Gfx.dx = 0;
        Gfx.dy = 0;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        MD.begin();
        var bg = BG[mTheme];
        var text = _pick(mTextC, TEXT[mTheme]);
        if (k < 4) {
            drawSlot(dc, k, bg, text, _pick(mOutlineC, OUTLINE[mTheme]));
        } else {
            drawArc(dc, k - 4, bg, text, _pick(mTrackC, TRACK[mTheme]));
        }
    }

    // Arc gauge i (0 TL, 1 TR, 2 BL, 3 BR): track, fill growing from the base end, icon at the
    // fill head (kept on the track), value along the arc.
    function drawArc(dc as Dc, i as Number, bg as Number, text as Number, track as Number) as Void {
        var opt = mArcs[i];
        if (opt == MD.NONE) { return; }
        var d = slotInfo(opt, i + 4);
        var prog = d[1];
        var color = arcColor(i, opt, d[2]);
        // Inset the fill by its cap radius so its round end never sticks out past the track:
        // both ends of every arc then stop at the same place.
        var capDeg = Math.toDegrees((ARC_W / 2.0) / ARC_R);
        var dir0 = ARC_END[i] > ARC_BASE[i] ? 1 : -1;
        var base = ARC_BASE[i] + dir0 * capDeg;
        var span = (ARC_END[i] - dir0 * capDeg) - base;           // signed: + grows clockwise, - counter-clockwise
        var dir = span > 0 ? 1 : -1;
        roundArc(dc, ARC_A[i], ARC_B[i], track, TRACK_W);

        // Icon rides the fill head, but never leaves the track: at least 10 degrees in from the
        // base end so an empty arc doesn't push it into the neighbouring circle.
        var p = (prog != null) ? (prog as Float) : 0.0;
        var head = base + span * p;
        if ((head - base) * dir < 2) {
            // Empty or nearly empty: one round dot at the start of the arc (a single cap).
            head = base;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(Gfx.sx(Gfx.px(CX, ARC_R, base)), Gfx.sy(Gfx.py(CY, ARC_R, base)), Gfx.s(ARC_W / 2.0));
        } else {
            roundArc(dc, dir > 0 ? base : head, dir > 0 ? head : base, color, ARC_W);
        }
        // Icon sits just past the fill head (3 degrees), kept on the track.
        var iconA = head + dir * 3;
        if ((iconA - base) * dir < 12) { iconA = base + dir * 12; }   // clear of the start dot
        // ...and never closer than 6 degrees to the arc end, so a full arc's icon clears the frame.
        if ((iconA - (ARC_END[i] - dir * 6)) * dir > 0) { iconA = ARC_END[i] - dir * 6; }
        var iconR = ICON_R;
        var ix = Gfx.px(CX, iconR, iconA);
        var iy = Gfx.py(CY, iconR, iconA);
        var icon = d[3] as Number;
        if (icon != MD.I_NONE) {
            var sz = 32;
            if (icon == MD.I_HEART) { sz = 36; }
            else if (icon == MD.I_BOLT) { sz = 30; }
            else if (icon >= MD.I_SUN && icon <= MD.I_STORM) { sz = 38; }
            Icons.small = true;
            Icons.draw(dc, icon, ix, iy, sz, color, bg, prog);
            Icons.small = false;
        } else if (d[4] != null) {
            Gfx.text(dc, ix, iy, fAodInfo, d[4] as String, color, Graphics.TEXT_JUSTIFY_CENTER);
        }
        arcText(dc, i, d[0] as String, text);
    }

    // Data for slot k (0..3 circles, 4..7 arcs): our own rendering, or the raw complication.
    function slotInfo(opt as Number, k as Number) as Array {
        return opt == MD.GENERIC ? MD.infoComp(mIds[k]) : MD.info(opt);
    }

    function arcColor(i as Number, opt as Number, dyn) as Number {
        var c = mArcColors[i];
        if (c == AUTO) {
            if (mTheme == 1) { return NAVY_ARCS[i]; }
            if (mTheme == 2) { return CHARCOAL_ACCENT; }
            if (mTheme == 3) { return CREAM_ACCENT; }
            c = DYNAMIC;
        }
        if (c == DYNAMIC) {
            return dyn != null ? dyn as Number : MD.color(opt);
        }
        return c;
    }

    // Arc on the rim (clock degrees a0 < a1) with round caps.
    function roundArc(dc as Dc, a0 as Numeric, a1 as Numeric, color as Number, w as Numeric) as Void {
        Gfx.arc(dc, CX, CY, ARC_R, a0, a1, color, w);
        var r = w / 2.0;
        dc.fillCircle(Gfx.sx(Gfx.px(CX, ARC_R, a0)), Gfx.sy(Gfx.py(CY, ARC_R, a0)), Gfx.s(r));
        dc.fillCircle(Gfx.sx(Gfx.px(CX, ARC_R, a1)), Gfx.sy(Gfx.py(CY, ARC_R, a1)), Gfx.s(r));
    }

    // Value text along the arc, tangential and reading upright (vector font, 33 px).
    function arcText(dc as Dc, i as Number, str as String, color as Number) as Void {
        if (str.length() > 8) { str = str.substring(0, 8); }
        var a = ARC_TEXT[i];
        var r = ARC_TEXT_R[i];
        if ((dc has :drawRadialText) && (Graphics has :getVectorFont)) {
            var px = Gfx.s(33);
            if (mVec == null || mVecSize != px) {
                mVec = Graphics.getVectorFont({:face => [Gfx.COND_REG, Gfx.COND, Gfx.SANS], :size => px});
                mVecSize = px;
            }
            if (mVec != null) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.drawRadialText(Gfx.sx(CX), Gfx.sy(CY), mVec as Graphics.VectorFont, str,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, 90 - a, Gfx.s(r),
                    i < 2 ? Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE : Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
                return;
            }
        }
        Gfx.text(dc, Gfx.px(CX, r, a), Gfx.py(CY, r, a), fValueSm, str, color, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Data circle i (0 top, 1 left, 2 right, 3 bottom).
    function drawSlot(dc as Dc, i as Number, bg as Number, text as Number, outline as Number) as Void {
        drawFrame(dc, i, outline);
        var opt = mSlots[i];
        if (opt == MD.NONE) { return; }
        var d = slotInfo(opt, i);
        var str = d[0] as String;
        if (d[4] != null) {
            // Text label (weekday, UV, WK) in place of the icon, 3 px lower than an icon.
            var lc = _pick(mWeekdayC, WEEKDAY[mTheme]);
            if (opt == MD.UV && d[2] != null) { lc = d[2] as Number; }
            Gfx.text(dc, ICON_X[i], SLOT_Y[i] - 17, fLabel, d[4] as String, lc, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var icon = d[3] as Number;
            var sz = ICON_SZ[i];
            if (icon >= MD.I_SUN && icon <= MD.I_STORM) { sz += 2; }
            Icons.draw(dc, icon, ICON_X[i], ICON_Y[i], sz, iconColor(opt, d[2]), bg, d[1]);
        }
        var f = Gfx.width(dc, str, fValue) <= 90 ? fValue : fValueSm;
        Gfx.text(dc, VALUE_X[i], VALUE_Y[i], f, str, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function iconColor(opt as Number, dyn) as Number {
        var c = mIconC;
        if (c == AUTO) {
            if (mTheme == 1) {
                if (opt == MD.CALENDAR) { return 0xC8CCD6; }
                if (opt == MD.SUNRISE || opt == MD.SUNSET || opt == MD.NEXT_SUN) { return 0xE8E070; }
                if (opt == MD.NOTIF) { return 0xE3A04E; }
            } else if (mTheme == 2) {
                return opt == MD.CALENDAR ? 0xE6E6E6 : CHARCOAL_ACCENT;
            } else if (mTheme == 3) {
                return CREAM_ICON;
            }
            c = DYNAMIC;
        }
        if (c == DYNAMIC) {
            return dyn != null ? dyn as Number : MD.color(opt);
        }
        return c;
    }

    // Full circle (or hexagon); the round screen clips the outer part, as in the mockup.
    function drawFrame(dc as Dc, i as Number, color as Number) as Void {
        if (mFrame == 2) { return; }
        var cx = SLOT_X[i];
        var cy = SLOT_Y[i];
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(Gfx.s(2.5));
        if (mFrame == 0) {
            dc.drawCircle(Gfx.sx(cx), Gfx.sy(cy), Gfx.s(CIRCLE_R));
            return;
        }
        // Hexagon with a vertex pointing at the face center (as in the reference): left/right slots are
        // pointy left/right, top/bottom slots pointy top/bottom.
        var r = CIRCLE_R + 3;
        var rot = (i == 0 || i == 3) ? Math.PI / 6 : 0.0;
        for (var k = 0; k < 6; k++) {
            var a0 = rot + Math.PI * k / 3;
            var a1 = rot + Math.PI * (k + 1) / 3;
            dc.drawLine(Gfx.sx(cx + r * Math.cos(a0)), Gfx.sy(cy + r * Math.sin(a0)),
                        Gfx.sx(cx + r * Math.cos(a1)), Gfx.sy(cy + r * Math.sin(a1)));
        }
    }

    function hourStr() as String {
        var h = System.getClockTime().hour;
        var is24 = mTimeFmt == 0 ? Data.is24() : mTimeFmt == 2;
        if (!is24) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return mLead ? h.format("%02d") : h.toString();
    }

    function drawTime(dc as Dc) as Void {
        var f = fTime as FontResource;
        // Hour Auto = the theme's gradient: solid down to 55% of the CSS line box, then to hourEnd.
        if (mHourC == AUTO) {
            drawDigits(dc, HOUR_Y, f, hourStr(), HOUR[mTheme], HOUR_END[mTheme], HOUR_Y + 6, 54);
        } else {
            drawColor(dc, HOUR_Y, f, hourStr(), mHourC);
        }
        drawColor(dc, MIN_Y, f, System.getClockTime().min.format("%02d"), _pick(mMinC, MINUTE[mTheme]));
    }

    // Solid color, or one of the gradient settings (negative value) over the digits' height.
    function drawColor(dc as Dc, y as Numeric, f as FontResource, str as String, c as Number) as Void {
        if (c >= 0) {
            Gfx.text(dc, CX, y, f, str, c, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var g = (-c - 2) * 2;
        if (g < 0 || g + 1 >= GRAD.size()) { g = 0; }
        drawDigits(dc, y, f, str, GRAD[g], GRAD[g + 1], y - DIGIT_H / 2, DIGIT_H);
    }

    // Vertical gradient c0 -> c1 between design y g0 and g0 + gh (solid outside), drawn as
    // horizontal bands with dc.setClip, the digits drawn once per band.
    function drawDigits(dc as Dc, y as Numeric, f as FontResource, str as String,
                        c0 as Number, c1 as Number, g0 as Numeric, gh as Numeric) as Void {
        if (c0 == c1) {
            Gfx.text(dc, CX, y, f, str, c0, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var w = dc.getWidth();
        var top = y - DIGIT_H / 2 - 4;
        var bot = y + DIGIT_H / 2 + 4;
        if (g0 > top) {   // solid part above the gradient
            var ys = Gfx.sy(top - 20);
            dc.setClip(0, ys, w, Gfx.sy(g0) - ys);
            Gfx.text(dc, CX, y, f, str, c0, Graphics.TEXT_JUSTIFY_CENTER);
            top = g0;
        }
        var n = 10;
        var h = (bot - top) / n.toFloat();
        for (var i = 0; i < n; i++) {
            var y0 = Gfx.sy(top + i * h);
            var y1 = i == n - 1 ? Gfx.sy(bot + 20) : Gfx.sy(top + (i + 1) * h);
            var t = ((top + (i + 0.5) * h) - g0) / gh.toFloat();
            t = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
            dc.setClip(0, y0, w, y1 - y0);
            Gfx.text(dc, CX, y, f, str, mix(c0, c1, t.toFloat()), Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.clearClip();
    }

    function mix(a as Number, b as Number, t as Float) as Number {
        var r = ((a >> 16) & 0xFF) + (((b >> 16) & 0xFF) - ((a >> 16) & 0xFF)) * t;
        var g = ((a >> 8) & 0xFF) + (((b >> 8) & 0xFF) - ((a >> 8) & 0xFF)) * t;
        var bl = (a & 0xFF) + ((b & 0xFF) - (a & 0xFF)) * t;
        return (r.toNumber() << 16) | (g.toNumber() << 8) | bl.toNumber();
    }

    // ---------------------------------------------------------------- always-on

    // Outlined grey digits and one "SAT 24 · ♥ 61" line; no arcs, no circles.
    function drawAod(dc as Dc) as Void {
        var f = fTime as FontResource;
        Gfx.text(dc, CX, HOUR_Y, f, hourStr(), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);
        Gfx.text(dc, CX, MIN_Y, f, System.getClockTime().min.format("%02d"), 0x8A8A8A, Graphics.TEXT_JUSTIFY_CENTER);

        var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var date = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][(d.day_of_week as Number) - 1] + " " + d.day + " · ";
        var hr = Data.fmt(Data.heartRate());
        var wd = Gfx.width(dc, date, fAodInfo);
        var wh = Gfx.width(dc, hr, fAodInfo);
        var total = wd + 14 + 3 + wh;
        var x = CX - total / 2;
        var y = 330;
        Gfx.text(dc, x, y, fAodInfo, date, 0x6A6A6A, Graphics.TEXT_JUSTIFY_LEFT);
        x += wd;
        Icons.draw(dc, MD.I_HEART, x + 7, y, 14, 0x6A6A6A, 0x000000, null);
        Gfx.text(dc, x + 17, y, fAodInfo, hr, 0x6A6A6A, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
