// config.dart — where the phone app finds the Django backend.
//
// Defaults to a LAN dev server; change it at runtime on the server-settings
// screen (tap the gear on the login page). The API base is serverUrl + '/api'.

class Config {
  // A phone can't reach the desktop's 127.0.0.1 — point at the machine's LAN
  // IP for development. Editable in-app and persisted.
  static const String defaultServerUrl = 'http://192.168.1.10:8000';
  static const String currency = '₪';
}
