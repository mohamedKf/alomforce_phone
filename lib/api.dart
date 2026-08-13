// api.dart — all HTTP with the AlomForce Django backend (JWT auth + storage).
//
// Staff sign in with their ID number, the same credential the desktop uses. The
// server is configurable (LAN dev server, production later) and persisted.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

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

  Future<dynamic> get(String path, {Map<String, String>? query, bool retry = true}) async {
    final uri = _u(path).replace(queryParameters: query);
    http.Response r;
    try {
      r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiError('Network error. Check your connection.');
    }
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return get(path, query: query, retry: false);
      await _sessionLost();
    }
    return _json(r);
  }

  Future<dynamic> post(String path, Map body, {bool retry = true}) async {
    http.Response r;
    try {
      r = await http
          .post(_u(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiError('Network error. Check your connection.');
    }
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
      throw ApiError('Network error. Check your connection.');
    }
    if (r.statusCode == 401 && retry) {
      if (await _doRefresh()) return patch(path, body, retry: false);
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
