import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PolarApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new PolarView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
