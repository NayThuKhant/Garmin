import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TerminalApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new TerminalView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
