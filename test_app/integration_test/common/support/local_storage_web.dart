import 'dart:js_interop';

/// `window.localStorage.setItem(key, value)`: throws whatever the browser
/// throws (typically `QuotaExceededError`) with no translation, the same
/// way `shared_preferences_web`'s own untranslated `setItem` call does
/// (`research-m13.findings.md` section 3).
@JS('localStorage.setItem')
external void setLocalStorageItem(String key, String value);

/// `window.localStorage.removeItem(key)`; never throws when [key] is
/// already absent.
@JS('localStorage.removeItem')
external void removeLocalStorageItem(String key);
