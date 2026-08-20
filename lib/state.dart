// state.dart — tiny app-wide state: boot, session, and login/logout signals.
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'push.dart';

class AppState extends ChangeNotifier {
  bool booting = true;
  bool get loggedIn => api.isLoggedIn;
  String get role => api.role;

  Future<void> boot() async {
    // A dead session has to reach the UI: the API layer clears the tokens but
    // only the app can swap the screen, so without this the user sat on an
    // error page with no way back to the login form.
    api.onAuthLost = notifyListeners;
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
    // A restored session is still a signed-in user, and the Firebase token can
    // change between launches -- so re-register rather than assuming the one
    // sent at the original login is still current. Not awaited: the app must
    // not wait on Firebase to draw its first screen.
    if (api.isLoggedIn) push.registerForUser();
    notifyListeners();
  }

  void onLoggedIn() {
    push.registerForUser();
    notifyListeners();
  }

  /// Rebuild the whole app (e.g. after the language changed) so the new locale
  /// and text direction take effect immediately.
  void languageChanged() => notifyListeners();

  Future<void> signOut() async {
    // Before logout, not after: the request that removes this registration has
    // to be authenticated, and logout throws the tokens away. Getting this
    // order wrong leaves a shared phone notifying whoever used it last.
    await push.unregister();
    await api.logout();
    notifyListeners();
  }
}

final appState = AppState();
