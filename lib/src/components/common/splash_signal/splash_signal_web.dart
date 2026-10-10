import 'package:web/web.dart' as web;

/// The event the splash screen dispatches on `window` when it ends the
/// first-frame hold; the app's page removes its own loader on it.
const splashShownEvent = 'stratum-splash-shown';

/// Tells the page that the splash screen shows its first frame: one
/// [splashShownEvent] on `window` (FO-03 US-12 FR-02 E02). The engine's own
/// `flutter-first-frame` event cannot tell it, since it fires on the first
/// framework frame whether frames are held or not.
void signalSplashShown() =>
    web.window.dispatchEvent(web.Event(splashShownEvent));
