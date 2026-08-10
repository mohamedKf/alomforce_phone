// state.dart — tiny app-wide state: boot, session, and login/logout signals.
import 'package:flutter/foundation.dart';

import 'api.dart';

class AppState extends ChangeNotifier {
  bool booting = true;
  bool get loggedIn => api.isLoggedIn;
  String get role => api.role;

  Future<void> boot() async {
    await api.loadServer();
    // Dev convenience: override the server and auto-login from --dart-define,
    // so a simulator run can start straight in the app. Nothing is hardcoded;
    // with no defines passed this is a no-op.
    const devServer = String.fromEnvironment('SERVER');
    const devId = String.fromEnvironment('AUTOLOGIN_ID');
    const devPw = String.fromEnvironment('AUTOLOGIN_PW');
    if (devServer.isNotEmpty) await api.setServer(devServer);
    // Note: the language is intentionally NOT overridable from --dart-define —
    // it must always come from the user's saved choice (api.loadServer above).
    if (devId.isNotEmpty && devPw.isNotEmpty) {
      // Dev: force the requested account, dropping any stored session first so
      // switching roles (worker -> driver) actually takes effect.
      await api.logout();
      try {
        await api.login(devId, devPw);
      } catch (_) {}
    } else {
      await api.tryRestore();
    }
    booting = false;
    notifyListeners();
  }

  void onLoggedIn() => notifyListeners();

  /// Rebuild the whole app (e.g. after the language changed) so the new locale
  /// and text direction take effect immediately.
  void languageChanged() => notifyListeners();

  Future<void> signOut() async {
    await api.logout();
    notifyListeners();
  }
}

final appState = AppState();
