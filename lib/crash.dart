// crash.dart — crash and error reporting with Sentry.
//
// The DSN is not baked into the build. The server hands it out from
// GET /config/ (with the environment name), the app keeps it, and the next
// launch starts Sentry before the first frame. On the launch that first
// learns the DSN, Sentry is started as soon as the config arrives, so that
// session reports too rather than waiting for a restart.
//
// With no DSN -- a server that has none configured, a fresh install before
// its first config -- every call here is a no-op and the app runs exactly as
// it did before this file existed.
//
// What is sent: uncaught Flutter and platform errors (the SDK hooks those
// itself), and API answers of 500 and above, once per endpoint per session.
// Who it is about: the numeric user id and the role, nothing else -- no name,
// no phone, no IP (sendDefaultPii stays off).
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config.dart';

class Crash {
  Crash._();
  static final Crash instance = Crash._();

  final _storage = const FlutterSecureStorage();
  String _dsn = '';
  String _environment = '';
  bool _starting = false;

  /// Endpoints already reported this session. A server that is down answers
  /// every request with the same 502; one message says so, fifty do not.
  final Set<String> _reported = {};

  /// Sentry's name for this build. package_info_plus is not a dependency, so
  /// the version is the one in Config.appVersion, copied from pubspec.yaml.
  static const release = 'alomforce_phone@${Config.appVersion}';

  bool get enabled => Sentry.isEnabled;

  /// Start the app. When a DSN was saved by a previous launch, Sentry wraps
  /// runApp so errors from the very first frame are caught; otherwise the
  /// app runs plainly and [apply] starts Sentry later if the server has one.
  Future<void> launch(Widget app) async {
    try {
      _dsn = await _storage.read(key: 'sentry_dsn') ?? '';
      _environment = await _storage.read(key: 'sentry_environment') ?? '';
    } catch (_) {
      _dsn = '';
    }
    if (_dsn.isEmpty) {
      runApp(app);
      return;
    }
    try {
      await SentryFlutter.init(_configure, appRunner: () => runApp(app));
    } catch (e) {
      // A malformed DSN must not keep the app off the screen.
      debugPrint('Crash reporting unavailable: $e');
      if (!Sentry.isEnabled) runApp(app);
    }
  }

  void _configure(SentryFlutterOptions options) {
    options.dsn = _dsn;
    options.release = release;
    if (_environment.isNotEmpty) options.environment = _environment;
    options.sendDefaultPii = false;
    options.debug = false;
    // Errors only. Performance tracing would send a span per screen and per
    // request, which is more than anyone here will read.
    options.tracesSampleRate = null;
  }

  /// The server's answer to GET /config/. Remembers the DSN for the next
  /// launch and, when this launch has none running yet, starts Sentry now.
  /// An empty DSN turns reporting off, here and on later launches.
  Future<void> apply(dynamic cfg) async {
    if (cfg is! Map) return;
    final dsn = (cfg['sentry_dsn'] ?? '').toString().trim();
    final env = (cfg['sentry_environment'] ?? '').toString().trim();
    if (dsn == _dsn && env == _environment) return;
    _dsn = dsn;
    _environment = env;
    try {
      await _storage.write(key: 'sentry_dsn', value: dsn);
      await _storage.write(key: 'sentry_environment', value: env);
    } catch (_) {}

    if (dsn.isEmpty) {
      if (Sentry.isEnabled) await Sentry.close();
      return;
    }
    if (Sentry.isEnabled || _starting) {
      // Already running from launch. A changed DSN or environment takes
      // effect next launch; restarting the SDK mid-session is not worth
      // the edge cases.
      return;
    }
    _starting = true;
    try {
      // Without appRunner: the app is already on screen. The SDK still hooks
      // FlutterError.onError and PlatformDispatcher.onError from here on.
      await SentryFlutter.init(_configure);
    } catch (e) {
      debugPrint('Crash reporting unavailable: $e');
    } finally {
      _starting = false;
    }
  }

  /// Who the reports are about: the numeric id and the role, nothing that
  /// names them. Call after sign-in and restore; pass an empty map on
  /// sign-out to clear it.
  Future<void> setUser(Map<String, dynamic> user) async {
    if (!Sentry.isEnabled) return;
    final id = user['id'];
    await Sentry.configureScope((scope) => scope.setUser(id == null
        ? null
        : SentryUser(
            id: id.toString(),
            data: {'role': (user['role'] ?? '').toString()},
          )));
  }

  /// An API call the server failed (status 500 and above). Reported once
  /// per endpoint per session: ids in the path are folded, so
  /// /orders/12/ and /orders/13/ are the same endpoint.
  void report(String path, int status, {String method = 'GET'}) {
    if (!Sentry.isEnabled) return;
    final key = '$method ${endpointKey(path)}';
    if (!_reported.add(key)) return;
    Sentry.captureMessage('API $status on $key', level: SentryLevel.error);
  }

  /// The path with every numeric segment replaced by {id}, and the /api
  /// prefix dropped, so it names the endpoint rather than the record.
  @visibleForTesting
  static String endpointKey(String path) {
    var p = path;
    if (p.startsWith('/api/')) p = p.substring(4);
    return p.replaceAll(RegExp(r'/\d+(?=/|$)'), '/{id}');
  }
}

final crash = Crash.instance;
