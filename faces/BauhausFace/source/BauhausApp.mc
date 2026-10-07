import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BauhausApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new BauhausView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
