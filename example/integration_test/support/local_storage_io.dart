/// Native targets never call this (every caller is gated behind `kIsWeb`);
/// the stub exists only so the conditional export compiles everywhere.
void setLocalStorageItem(String key, String value) {}

/// Native targets never call this (every caller is gated behind `kIsWeb`).
void removeLocalStorageItem(String key) {}
