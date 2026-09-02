// api.dart — all HTTP with the AlomForce Django backend (JWT auth + storage).
//
// Staff sign in with their ID number, the same credential the desktop uses. The
// server is configurable (LAN dev server, production later) and persisted.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'offline.dart';

/// Writes that are safe to make offline and replay later: idempotent or
/// low-harm-on-duplicate. Value-creating writes (stock movements, order /
/// invoice / client creation) are deliberately NOT here — a replayed duplicate
/// would double-count or create twice, and they need a live server result.
bool _isQueueable(String path) {
  return path.contains('/attendance/clock_in') ||
      path.contains('/attendance/clock_out') ||
      path.contains('/set_status') ||
      path.contains('/line_action') ||
      path.contains('/corrections');
}

class ApiError implements Exception {
  final String message;
  final int? status;
  final Map<String, dynamic> fields;
  ApiError(this.message, {this.status, this.fields = const {}});
  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api instance = Api._();

  final _storage = const FlutterSecureStorage();
  String? _access;
  String? _refresh;
  Map<String, dynamic> user = {};

  String _serverUrl = Config.defaultServerUrl;
  String get serverUrl => _serverUrl;
  String get apiBase => '$_serverUrl/api';

  // UI language preference (persisted). Defaults to Hebrew until the user
  // picks another in Settings; the saved choice then wins on every launch.
  String _language = 'he';
  String get language => _language;

  String get role => (user['role'] ?? '').toString();
  String get fullName => (user['full_name'] ?? '').toString();

  Uri _u(String path) => Uri.parse('$apiBase$path');

  // ---- server settings ----
  static String normalizeServer(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> loadServer() async {
    final saved = await _storage.read(key: 'server_url');
    if (saved != null && saved.isNotEmpty) _serverUrl = saved;
    final lang = await _storage.read(key: 'language');
    if (lang != null && lang.isNotEmpty) _language = lang;
  }

  Future<void> setServer(String url) async {
    _serverUrl = normalizeServer(url);
    await _storage.write(key: 'server_url', value: _serverUrl);
  }

  Future<void> setLanguage(String code) async {
    _language = code;
    await _storage.write(key: 'language', value: code);
  }

  // Reachable if the server answers at all (401 still means it's there).
  Future<bool> testServer(String url) async {
    final probe = '${normalizeServer(url)}/api/';
    try {
      final r =
          await http.get(Uri.parse(probe)).timeout(const Duration(seconds: 8));
      return r.statusCode > 0;
    } catch (_) {
      return false;
    }
  }

  // ---- session ----
  bool get isLoggedIn => _access != null && user.isNotEmpty;

  Future<bool> tryRestore() async {
    _access = await _storage.read(key: 'access');
    _refresh = await _storage.read(key: 'refresh');
    final u = await _storage.read(key: 'user');
    if (u != null) {
      try {
        user = jsonDecode(u) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (_refresh == null) return false;
    // The stored access token may be stale; refresh once to confirm the session.
    return _doRefresh();
  }

  Future<void> _persist() async {
    if (_access != null) await _storage.write(key: 'access', value: _access);
    if (_refresh != null) await _storage.write(key: 'refresh', value: _refresh);
    await _storage.write(key: 'user', value: jsonEncode(user));
  }

  Future<void> logout() async {
    _access = _refresh = null;
    user = {};
    await _storage.delete(key: 'access');
    await _storage.delete(key: 'refresh');
    await _storage.delete(key: 'user');
  }

  Future<void> login(String identifier, String password) async {
    http.Response r;
    try {
      r = await http
          .post(_u('/auth/login/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'identifier': identifier, 'password': password}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiError('Cannot reach the server. Check the address and Wi-Fi.');
    }
    if (r.statusCode != 200) {
      throw ApiError(_describe(r), status: r.statusCode);
    }
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    _access = d['access'];
    _refresh = d['refresh'];
    user = (d['user'] ?? {}) as Map<String, dynamic>;
    await _persist();
  }

  /// Create an account and sign in with it.
  ///
  /// The server returns the same token pair as a login, so there is no reason
  /// to make somebody type their details and then immediately type them again.
  Future<void> register({
    required bool asManager,
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String businessName = '',
    String idNumber = '',
    String registerCode = '',
  }) async {
    final body = <String, dynamic>{
      'account': asManager ? 'manager' : 'client',
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'password': password,
      'language': _language,
    };
    if (asManager) {
      body['id_number'] = idNumber;
      body['register_code'] = registerCode;
    } else {
      body['business_name'] = businessName;
    }

    http.Response r;
    try {
      r = await http
          .post(_u('/auth/register/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiError('Cannot reach the server. Check the address and Wi-Fi.');
    }
    if (r.statusCode != 201) {
      throw ApiError(_describe(r), status: r.statusCode);
    }
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    _access = d['access'];
    _refresh = d['refresh'];
    user = (d['user'] ?? {}) as Map<String, dynamic>;
    await _persist();
  }

  Future<bool> _doRefresh() async {
    if (_refresh == null) return false;
    try {
      final r = await http
          .post(_u('/auth/refresh/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh': _refresh}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return false;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      _access = d['access'];
      if (d['refresh'] != null) _refresh = d['refresh']; // rotation
      await _persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- requests with 401-refresh retry ----
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // Django's LocaleMiddleware is installed on the server, so a status
        // name or a validation message comes back in whatever language is
        // asked for -- and without this header that is English, whatever the
        // person is reading the app in. Every "Confirmed" sitting in the
        // middle of a Hebrew screen was this line missing.
        'Accept-Language': _language,
        if (_access != null) 'Authorization': 'Bearer $_access',
      };

  /// Called when the session can no longer be recovered, so the app can show
  /// the login screen. Set by AppState; unset in tests.
  void Function()? onAuthLost;

  /// The refresh token is dead too, so nothing here can be signed again.
  ///
  /// Without this a 401 fell through to _json() and surfaced SimpleJWT's own
  /// wording -- "Given token not valid for any token type" -- on every screen,
  /// with the dead tokens still in storage, so the app stayed stuck on that
  /// error until someone found the sign-out button.
  Future<Never> _sessionLost() async {
    await logout();
    onAuthLost?.call();
    throw ApiError('Your session has expired. Please sign in again.',
        status: 401);
  }

  String _cacheKey(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final keys = query.keys.toList()..sort();
    return '$path?${keys.map((k) => '$k=${query[k]}').join('&')}';
  }

  Future<dynamic> get(String path, {Map<String, String>? query, bool retry = true}) async {
    final uri = _u(path).replace(queryParameters: query);
    http.Response r;
    try {
      r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Offline: hand back the last successful answer for this URL if we have
      // one, so the screen shows real (if stale) data instead of an error.
      offline.online.value = false;
      final cached = await offline.cacheGet(_cacheKey(path, query));
      if (cached != null) return cached;
      throw ApiError('Network error. Check your connection.');
    }
    offline.online.value = true;
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return get(path, query: query, retry: false);
      await _sessionLost();
    }
    final data = _json(r); // throws on >= 400, so only 2xx reaches the cache
    await offline.cachePut(_cacheKey(path, query), data);
    syncOutbox(); // opportunistic: a working GET means the network is back
    return data;
  }

  Future<dynamic> post(String path, Map body, {bool retry = true}) async {
    http.Response r;
    try {
      r = await http
          .post(_u(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      offline.online.value = false;
      if (_isQueueable(path)) {
        await offline.enqueue('POST', path, body);
        return {'_queued': true};
      }
      throw ApiError('Network error. Check your connection.');
    }
    offline.online.value = true;
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return post(path, body, retry: false);
      await _sessionLost();
    }
    return _json(r);
  }

  Future<dynamic> patch(String path, Map body, {bool retry = true}) async {
    http.Response r;
    try {
      r = await http
          .patch(_u(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      offline.online.value = false;
      if (_isQueueable(path)) {
        await offline.enqueue('PATCH', path, body);
        return {'_queued': true};
      }
      throw ApiError('Network error. Check your connection.');
    }
    offline.online.value = true;
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return patch(path, body, retry: false);
      await _sessionLost();
    }
    return _json(r);
  }

  // ---- offline write queue sync ----
  bool _syncing = false;

  /// Replay queued offline writes for the signed-in user, in order. Called when
  /// the network returns (a successful GET, or a connectivity change). A write
  /// the server rejects (4xx — e.g. an already-reviewed correction, or a second
  /// clock-in) is dropped rather than retried forever; a network/5xx failure
  /// stops the run so order is preserved and it's retried next time.
  Future<void> syncOutbox() async {
    if (_syncing || _access == null) return;
    _syncing = true;
    try {
      final rows = await offline.pendingWrites();
      for (final row in rows) {
        final id = row['id'] as int;
        final method = row['method'] as String;
        final path = row['path'] as String;
        final body = jsonDecode(row['body'] as String) as Map;
        try {
          await _replay(method, path, body);
        } on ApiError catch (e) {
          if (e.status != null && e.status! >= 400 && e.status! < 500 &&
              e.status != 401) {
            await offline.removeWrite(id); // server refused it — drop, move on
            continue;
          }
          break; // auth/5xx/network — stop, keep order, try again later
        } catch (_) {
          break; // network down — stop and retry later
        }
        await offline.removeWrite(id);
      }
    } finally {
      _syncing = false;
    }
  }

  /// One replay attempt with auth + a single 401-refresh. Never re-queues (that
  /// would loop): a network failure here throws and syncOutbox stops.
  Future<dynamic> _replay(String method, String path, Map body,
      {bool retry = true}) async {
    final r = method == 'PATCH'
        ? await http
            .patch(_u(path), headers: _headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20))
        : await http
            .post(_u(path), headers: _headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return _replay(method, path, body, retry: false);
      throw ApiError('Session expired.', status: 401);
    }
    return _json(r);
  }

  /// DELETE with a body -- unusual, but the device endpoint identifies the
  /// registration to remove by the token in it, and a token is too long to
  /// put in a URL.
  Future<dynamic> delete(String path, Map body, {bool retry = true}) async {
    http.Response r;
    try {
      r = await http
          .delete(_u(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiError('Network error. Check your connection.');
    }
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return delete(path, body, retry: false);
      await _sessionLost();
    }
    return _json(r);
  }

  Future<Uint8List> getBytes(String path, {bool retry = true}) async {
    http.Response r;
    try {
      r = await http.get(_u(path), headers: _headers).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiError('Network error. Check your connection.');
    }
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return getBytes(path, retry: false);
      await _sessionLost();
    }
    if (r.statusCode >= 400) throw ApiError(_describe(r), status: r.statusCode);
    return r.bodyBytes;
  }

  /// POST a file (e.g. a captured signature) as multipart, with text fields.
  Future<dynamic> uploadBytes(
    String path, {
    required String field,
    required Uint8List bytes,
    required String filename,
    Map<String, String>? fields,
    bool retry = true,
  }) async {
    final req = http.MultipartRequest('POST', _u(path));
    if (_access != null) req.headers['Authorization'] = 'Bearer $_access';
    fields?.forEach((k, v) => req.fields[k] = v);
    req.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    http.Response r;
    try {
      final sr = await req.send().timeout(const Duration(seconds: 30));
      r = await http.Response.fromStream(sr);
    } catch (_) {
      throw ApiError('Network error. Check your connection.');
    }
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) {
        return uploadBytes(path,
            field: field, bytes: bytes, filename: filename,
            fields: fields, retry: false);
      }
      await _sessionLost();
    }
    return _json(r);
  }

  dynamic _json(http.Response r) {
    if (r.statusCode == 204 || r.body.isEmpty) return null;
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {
      if (r.statusCode >= 400) throw ApiError('Unexpected response (${r.statusCode}).');
      return null;
    }
    if (r.statusCode >= 400) {
      throw ApiError(_describeBody(body, r.statusCode),
          status: r.statusCode,
          fields: body is Map<String, dynamic> ? body : const {});
    }
    return body;
  }

  String _describe(http.Response r) {
    try {
      return _describeBody(jsonDecode(r.body), r.statusCode);
    } catch (_) {
      return 'Request failed (${r.statusCode}).';
    }
  }

  String _describeBody(dynamic body, int status) {
    if (body is Map) {
      for (final key in ['detail', 'error', 'message']) {
        if (body[key] != null) return body[key].toString();
      }
      final parts = <String>[];
      body.forEach((k, v) {
        final val = v is List ? v.join('; ') : v.toString();
        parts.add('$k: $val');
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return 'Request failed ($status).';
  }
}

final api = Api.instance;
