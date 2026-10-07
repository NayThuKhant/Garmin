import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SunApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new SunView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
