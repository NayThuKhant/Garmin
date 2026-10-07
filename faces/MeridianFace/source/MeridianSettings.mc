import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch "Customize" menu (long-press the face). Three levels:
//   groups (Data fields, Style, ...) -> settings in the group (current value as sub-label)
//   -> option list (picking one saves it and redraws the face).
// The lists come from MeridianMenuData.mc, generated together with the phone settings.

function meridianApplySettings() as Void {
    (Application.getApp() as MeridianApp).onSettingsChanged();
}

function meridianCurrentLabel(key as String, listId as Number) as String {
    var v = Application.Properties.getValue(key);
    if (listId < 0) {
        return (v instanceof Boolean && v) ? "On" : "Off";
    }
    var values = MenuData.values(listId);
    var labels = MenuData.labels(listId);
    for (var i = 0; i < values.size(); i++) {
        if (values[i] == v) { return labels[i]; }
    }
    return "";
}

// ---- level 1: groups ----

class MeridianSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Meridian"});
        var titles = MenuData.groupTitles();
        for (var g = 0; g < titles.size(); g++) {
            addItem(new WatchUi.MenuItem(titles[g], null, g, null));
        }
    }
}

class MeridianSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var g = item.getId() as Number;
        WatchUi.pushView(new MeridianGroupMenu(g), new MeridianGroupDelegate(), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ---- level 2: settings in a group ----

class MeridianGroupMenu extends WatchUi.Menu2 {
    function initialize(g as Number) {
        Menu2.initialize({:title => MenuData.groupTitles()[g]});
        var items = MenuData.groupItems(g);
        for (var i = 0; i < items.size(); i++) {
            var it = items[i];
            var key = it[0] as String;
            var listId = it[2] as Number;
            if (listId < 0) {
                var v = Application.Properties.getValue(key);
                addItem(new WatchUi.ToggleMenuItem(it[1] as String, null, [key, listId],
                    v instanceof Boolean ? v : false, null));
            } else {
                addItem(new WatchUi.MenuItem(it[1] as String, meridianCurrentLabel(key, listId), [key, listId], null));
            }
        }
    }
}

class MeridianGroupDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Array;
        var key = id[0] as String;
        var listId = id[1] as Number;
        if (listId < 0) {
            Application.Properties.setValue(key, (item as WatchUi.ToggleMenuItem).isEnabled());
            meridianApplySettings();
            return;
        }
        WatchUi.pushView(new MeridianOptionMenu(key, item.getLabel(), listId),
                         new MeridianOptionDelegate(key, item), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ---- level 3: options for one setting ----

class MeridianOptionMenu extends WatchUi.Menu2 {
    function initialize(key as String, title as String, listId as Number) {
        Menu2.initialize({:title => title});
        var labels = MenuData.labels(listId);
        var values = MenuData.values(listId);
        var cur = Application.Properties.getValue(key);
        var focus = 0;
        for (var i = 0; i < labels.size(); i++) {
            addItem(new WatchUi.MenuItem(labels[i], null, values[i], null));
            if (values[i] == cur) { focus = i; }
        }
        setFocus(focus);
    }
}

class MeridianOptionDelegate extends WatchUi.Menu2InputDelegate {
    var mKey as String;
    var mParent as WatchUi.MenuItem;

    function initialize(key as String, parent as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        mKey = key;
        mParent = parent;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Application.Properties.setValue(mKey, item.getId() as Number);
        mParent.setSubLabel(item.getLabel());
        meridianApplySettings();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
