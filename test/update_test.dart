// The update notice compares build numbers, because that is the versionCode
// Android itself compares. Only a strictly newer build is worth interrupting
// someone's shift for, and nothing the server sends may throw.
import 'package:flutter_test/flutter_test.dart';
import 'package:alomforce_phone/update.dart';

/// A /config/ answer carrying one published android build.
Map<String, dynamic> cfgWith(dynamic android) => {
      'sentry_dsn': '',
      'update': {'android': android, 'desktop': null},
    };

Map<String, dynamic> android(dynamic build) => {
      'version': '1.2.0',
      'build': build,
      'url': 'https://example.test/AlomForce-1.2.0-14.apk',
      'notes': 'Faster stock screen',
    };

void main() {
  test('the build number is the part after the plus', () {
    expect(AppUpdate.buildOf('1.1.0+13'), 13);
    expect(AppUpdate.buildOf('2.0.0+107'), 107);
    // Nothing to compare: no build part, an empty one, or not a number.
    expect(AppUpdate.buildOf('1.1.0'), isNull);
    expect(AppUpdate.buildOf('1.1.0+'), isNull);
    expect(AppUpdate.buildOf('1.1.0+beta'), isNull);
    expect(AppUpdate.buildOf(''), isNull);
  });

  test('a newer build is offered, with its version and notes', () {
    final r = AppUpdate.offered(cfgWith(android(14)), currentBuild: 13);
    expect(r, isNotNull);
    expect(r!.build, 14);
    expect(r.version, '1.2.0');
    expect(r.notes, 'Faster stock screen');
    expect(r.url, endsWith('.apk'));
  });

  test('the same or an older build says nothing', () {
    expect(AppUpdate.offered(cfgWith(android(13)), currentBuild: 13), isNull);
    expect(AppUpdate.offered(cfgWith(android(12)), currentBuild: 13), isNull);
    // Numeric, not string: "9" must not beat "13" the way text would.
    expect(AppUpdate.offered(cfgWith(android(9)), currentBuild: 13), isNull);
  });

  test('a build the user dismissed stays dismissed, a later one does not', () {
    expect(
        AppUpdate.offered(cfgWith(android(14)),
            currentBuild: 13, dismissedBuild: 14),
        isNull);
    expect(
        AppUpdate.offered(cfgWith(android(15)),
            currentBuild: 13, dismissedBuild: 14),
        isNotNull);
  });

  test('nothing published means silence, not "up to date"', () {
    expect(AppUpdate.offered(cfgWith(null), currentBuild: 13), isNull);
    expect(AppUpdate.offered({'update': null}, currentBuild: 13), isNull);
    expect(AppUpdate.offered({'sentry_dsn': ''}, currentBuild: 13), isNull);
    // A desktop-only release is not this app's business.
    expect(
        AppUpdate.offered({
          'update': {
            'android': null,
            'desktop': {'version': '1.2.0', 'build': 14, 'url': 'x.exe'}
          }
        }, currentBuild: 13),
        isNull);
  });

  test('malformed input answers null instead of throwing', () {
    for (final cfg in <dynamic>[
      null,
      'not a map',
      42,
      {'update': 'soon'},
      {'update': {'android': 'soon'}},
      cfgWith({'build': 'fourteen', 'url': 'https://x/y.apk'}),
      cfgWith({'version': '1.2.0', 'url': 'https://x/y.apk'}), // no build
      cfgWith({'build': 14, 'version': '1.2.0'}), // no url to open
      cfgWith({'build': 14, 'url': '   '}), // blank url
    ]) {
      expect(AppUpdate.offered(cfg, currentBuild: 13), isNull,
          reason: 'offered($cfg)');
    }
  });

  test('an unreadable own version means no notice', () {
    // Config.appVersion without a build part: nothing to compare against, so
    // the app keeps quiet rather than guessing from the version name.
    expect(AppUpdate.offered(cfgWith(android(99)), currentBuild: null), isNull);
  });

  test('this build advertises a real build number', () {
    // Guards the pubspec/Config copy: a version with no '+13' would silently
    // disable the notice everywhere.
    expect(AppUpdate.myBuild, isNotNull);
  });

  test('nothing is offered before any config arrives', () {
    expect(appUpdate.available.value, isNull);
  });
}
