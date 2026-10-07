import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DialApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new DialView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
