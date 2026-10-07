import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Face AA · Words — mockups/Words.dc.html (active), mockups/WordsAOD.dc.html (always-on).
// 11x10 English word clock in 5-minute steps, 0-4 extra minutes as dots.
class WordsView extends WatchUi.WatchFace {

    var mSleep as Boolean = false;

    const UNLIT = 0x1F1F1F;

    // Letter grid (row strings, 11 cells each), cells 22x22 from (74, 86).
    const GRID = [
        "ITLISASAMPM",
        "ACQUARTERDC",
        "TWENTYFIVEX",
        "HALFSTENFTO",
        "PASTERUNINE",
        "ONESIXTHREE",
        "FOURFIVETWO",
        "EIGHTELEVEN",
        "SEVENTWELVE",
        "TENSEOCLOCK"
    ];

    // Words as [row, col, length].
    const W_IT = [0, 0, 2];
    const W_IS = [0, 3, 2];
    const W_QUARTER = [1, 2, 7];
    const W_TWENTY = [2, 0, 6];
    const W_FIVE = [2, 6, 4];
    const W_HALF = [3, 0, 4];
    const W_TEN = [3, 5, 3];
    const W_TO = [3, 9, 2];
    const W_PAST = [4, 0, 4];
    const W_OCLOCK = [9, 5, 6];
    // Hours 1..12.
    const HOURS = [
        [5, 0, 3], [6, 8, 3], [5, 6, 5], [6, 0, 4], [6, 4, 4], [5, 3, 3],
        [8, 0, 5], [7, 0, 5], [4, 7, 4], [9, 0, 3], [7, 5, 6], [8, 5, 6]
    ];

    var fGrid as FontResource;
    var fDate as FontResource;
    var fAodDate as FontResource;
    var fStat as FontResource;

    // Lit cells: one 11-bit mask per row, rebuilt when the 5-minute slot changes.
    var mMask as Array<Number> = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    var mKey as Number = -1;

    function initialize() {
        WatchFace.initialize();
        fGrid = WatchUi.loadResource(Rez.Fonts.Grid) as FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
        fAodDate = WatchUi.loadResource(Rez.Fonts.AodDate) as FontResource;
        fStat = WatchUi.loadResource(Rez.Fonts.Stat) as FontResource;
    }

    function onEnterSleep() as Void {
        mSleep = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mSleep = false;
        WatchUi.requestUpdate();
    }

    function light(w as Array<Number>) as Void {
        var bits = ((1 << w[2]) - 1) << w[1];
        mMask[w[0]] = mMask[w[0]] | bits;
    }

    function updateMask(hour as Number, min as Number) as Void {
        var slot = min / 5;
        var key = hour * 12 + slot;
        if (key == mKey) { return; }
        mKey = key;
        for (var i = 0; i < 10; i++) { mMask[i] = 0; }
        light(W_IT);
        light(W_IS);
        var h = hour;
        if (slot == 1 || slot == 11) { light(W_FIVE); }
        else if (slot == 2 || slot == 10) { light(W_TEN); }
        else if (slot == 3 || slot == 9) { light(W_QUARTER); }
        else if (slot == 4 || slot == 8) { light(W_TWENTY); }
        else if (slot == 5 || slot == 7) { light(W_TWENTY); light(W_FIVE); }
        else if (slot == 6) { light(W_HALF); }
        if (slot == 0) {
            light(W_OCLOCK);
        } else if (slot <= 6) {
            light(W_PAST);
        } else {
            light(W_TO);
            h += 1;
        }
        h = h % 12;
        if (h == 0) { h = 12; }
        light(HOURS[h - 1] as Array<Number>);
    }

    function onUpdate(dc as Dc) as Void {
        Gfx.setup(dc);
        var t = Data.clock();
        var min = t.min as Number;
        updateMask(t.hour as Number, min);
        if (mSleep) {
            Gfx.aodShift();
        }
        var aod = mSleep;

        // Date: top 54, 11px, ls 4.
        Gfx.text(dc, 195, 61.5, aod ? fAodDate : fDate, Data.dateStr(),
                 aod ? 0x5A5A5A : 0x7A7A7A, Graphics.TEXT_JUSTIFY_CENTER);

        // Grid: one glyph centered in each 22x22 cell.
        var lit = aod ? 0x8A8A8A : 0xFFFFFF;
        for (var r = 0; r < 10; r++) {
            var row = GRID[r] as String;
            var m = mMask[r];
            var cy = 97 + 22 * r;
            for (var c = 0; c < 11; c++) {
                var on = (m & (1 << c)) != 0;
                if (aod && !on) { continue; }
                Gfx.text(dc, 85 + 22 * c, cy, fGrid, row.substring(c, c + 1) as String,
                         on ? lit : UNLIT, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Minute dots: 4 x 5px, gap 9, centred at y 318.5.
        var acc = Gfx.accent(0xFFD27A);
        var n = min % 5;
        for (var i = 0; i < 4; i++) {
            var on = i < n;
            if (aod && !on) { continue; }
            dc.setColor(on ? (aod ? 0x5A5A5A : acc) : UNLIT, Graphics.COLOR_TRANSPARENT);
            var r = Gfx.k * 2.5;
            dc.fillCircle(Gfx.sx(174 + 14 * i), Gfx.sy(318.5), r < 1.5 ? 1.5 : r);
        }

        if (aod) { Gfx.aodMask(dc); return; }

        // Stats: 11px, gap 12, top 334.
        var hr = Data.heartRate();
        var parts = [(hr != null ? hr.toString() : "--") + " BPM", Data.thousands(Data.steps()), Data.battery() + "%"];
        var total = 24.0;
        for (var i = 0; i < 3; i++) {
            total += Gfx.width(dc, parts[i] as String, fStat);
        }
        var x = 195 - total / 2;
        for (var i = 0; i < 3; i++) {
            Gfx.text(dc, x, 341.5, fStat, parts[i] as String, 0x8A8A8A, Graphics.TEXT_JUSTIFY_LEFT);
            x += Gfx.width(dc, parts[i] as String, fStat) + 12;
        }
        if (mSleep) {
            Gfx.aodMask(dc);
        }
    }
}
