// config.dart — where the phone app finds the Django backend.
//
// Defaults to a LAN dev server; change it at runtime on the server-settings
// screen (tap the gear on the login page). The API base is serverUrl + '/api'.

class Config {
  // The deployed backend on Railway. A device with no saved server setting
  // starts here, so a fresh install works without anyone typing a LAN IP.
  //
  // For local development point this at the machine's LAN IP instead (a phone
  // cannot reach the desktop's 127.0.0.1), e.g. http://192.168.1.10:8001 —
  // or leave it and override on the server-settings screen, which persists.
  // Note iOS blocks plain http:// by default, so a LAN override needs an ATS
  // exception; the https Railway URL does not.
  static const String defaultServerUrl =
      'https://alomforce-production.up.railway.app';
  static const String currency = '₪';
}
