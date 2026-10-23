import 'web/web_tab_lock_stub.dart' if (dart.library.js_interop) 'web/web_tab_lock.dart' as impl;

/// Siehe `acquireWebTabLock`: nur im Browser wirksam.
Future<bool> acquireTabLock() => impl.acquireWebTabLock();
