// update.dart — "a newer build is out there" notice.
//
// The server publishes the current APK in GET /config/:
//
//   "update": {"android": {"version": "1.1.0", "build": 13,
//                          "url": ".../AlomForce-1.1.0-13.apk",
//                          "notes": "free text"}, "desktop": {...}}
//
// Only the android entry concerns the phone. null means nothing has been
// published, and then the app says nothing at all -- never "you are up to
// date", which is noise on a screen someone is working on.
//
// What is compared is the build number, the integer after '+' in
// Config.appVersion, because that is the versionCode Android itself compares
// when deciding whether an APK is an upgrade. A version *name* ("1.1.0") is
// free text and two builds can share one. Anything unreadable on either side
// -- no '+', a non-numeric build, a missing url -- means no notice rather
// than a guess.
//
// Installing is Android's job: the url is a plain .apk, so Download hands it
// to the browser and the system package installer takes it from there.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// A published build, as the server describes it.
class AppRelease {
  final String version;
  final int build;
  final String url;
  final String notes;
  const AppRelease({
    required this.version,
    required this.build,
    required this.url,
    this.notes = '',
  });
}

class AppUpdate {
  AppUpdate._();
  static final AppUpdate instance = AppUpdate._();

  static const _dismissedKey = 'update_dismissed_build';

  final _storage = const FlutterSecureStorage();

  /// The build worth telling the user about, or null for "say nothing".
  /// Watched by the banner on every role home.
  final ValueNotifier<AppRelease?> available = ValueNotifier<AppRelease?>(null);

  /// The integer after '+' in a Flutter version string ('1.1.0+13' -> 13).
  /// Null when there is no build part or it is not a number.
  @visibleForTesting
  static int? buildOf(String version) {
    final plus = version.lastIndexOf('+');
    if (plus < 0 || plus == version.length - 1) return null;
    return int.tryParse(version.substring(plus + 1).trim());
  }

  /// This app's own build number, or null if Config.appVersion carries none.
  static int? get myBuild => buildOf(Config.appVersion);

  /// What (if anything) to offer, given the server's whole /config/ answer.
  ///
  /// Pure and total: every shape of rubbish -- a string where a map belongs,
  /// a build of "soon", a missing url -- answers null instead of throwing.
  /// [dismissedBuild] is the build the user already waved away; a later one
  /// still shows.
  @visibleForTesting
  static AppRelease? offered(
    dynamic cfg, {
    required int? currentBuild,
    int dismissedBuild = 0,
  }) {
    if (cfg is! Map || currentBuild == null) return null;
    final update = cfg['update'];
    if (update is! Map) return null;
    final android = update['android'];
    if (android is! Map) return null;

    final build = int.tryParse((android['build'] ?? '').toString().trim());
    if (build == null) return null;
    // Strictly newer than this build, and newer than whatever was dismissed.
    if (build <= currentBuild || build <= dismissedBuild) return null;

    final url = (android['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;

    return AppRelease(
      version: (android['version'] ?? '').toString().trim(),
      build: build,
      url: url,
      notes: (android['notes'] ?? '').toString().trim(),
    );
  }

  /// The server's answer to GET /config/, arriving after login or restore.
  Future<void> apply(dynamic cfg) async {
    available.value = offered(
      cfg,
      currentBuild: myBuild,
      dismissedBuild: await _dismissedBuild(),
    );
  }

  /// Hide the notice and remember the build, so the same version does not ask
  /// again on every launch. A newer one later is a new question.
  Future<void> dismiss() async {
    final release = available.value;
    available.value = null;
    if (release == null) return;
    try {
      await _storage.write(key: _dismissedKey, value: release.build.toString());
    } catch (_) {
      // A device that refuses to keep the flag just gets asked again; that is
      // better than losing the dismissal this session too.
    }
  }

  Future<int> _dismissedBuild() async {
    try {
      final saved = await _storage.read(key: _dismissedKey);
      return int.tryParse((saved ?? '').trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

final appUpdate = AppUpdate.instance;
