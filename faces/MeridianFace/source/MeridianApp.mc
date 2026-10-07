import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MeridianApp extends Application.AppBase {

    var mView as MeridianView or Null = null;
    var mEdit as Boolean = false;   // started by the native watch-face editor (MeridianNative.mc)

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        if (state != null && state[:launchedFromWatchFaceSettingsEditor] == true) {
            mEdit = true;
        }
    }

    // The delegate handles the native editor (edit mode) and long-press-to-open-app (normal mode).
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new MeridianView(mEdit);
        mView = v;
        return [v, new MeridianDelegate(v)];
    }

    // On-watch Menu2 customization (MeridianSettings.mc) for devices that support getSettingsView
    // (API < 5.1: vivoactive 5, Venu 3, FR265/965, epix 2, ...). Devices with the native editor
    // never call it.
    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return [new MeridianSettingsMenu(), new MeridianSettingsDelegate()];
    }

    function onSettingsChanged() as Void {
        if (mView != null) {
            (mView as MeridianView).loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
