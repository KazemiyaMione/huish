import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _baseUrl = 'https://i.ilife798.com';
  static const _keyToken = 'auth_token';
  static const _keyUid = 'auth_uid';
  static const _keyEid = 'auth_eid';

  // SHA256 fingerprints of trusted certificates (uppercase hex, colon-separated)
  // Get them: openssl s_client -connect i.ilife798.com:443 -servername i.ilife798.com </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256
  static const _pinnedCerts = <String>{
    // Replace with real fingerprint from the server
    'PLACEHOLDER',
  };

  late final http.Client _client;

  String? _token;
  String? _uid;
  String? _eid;

  ApiClient() {
    _client = _createPinnedClient();
  }

  static String _certSha256(X509Certificate cert) {
    final hash = crypto.sha256.convert(cert.der);
    return hash.toString(); // lowercase hex
  }

  http.Client _createPinnedClient() {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 15);
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (host != 'i.ilife798.com') return false;
      if (_pinnedCerts.contains('PLACEHOLDER')) return true; // not configured yet
      final fingerprint = _certSha256(cert);
      return _pinnedCerts.contains(fingerprint);
    };
    return IOClient(httpClient);
  }

  Map<String, String> get _baseHeaders => {
        'ApplicationType': '1,1',
        'VersionCode': '3.1.4',
        'user-agent': 'Android_ilife798_3.1.4',
      };

  Map<String, String> get _authHeaders {
    final h = <String, String>{..._baseHeaders};
    final t = _token;
    if (t != null) h['Authorization'] = t;
    return h;
  }

  double _randS() {
    final rng = Random();
    return rng.nextDouble();
  }

  /// Fetch captcha image. Returns raw bytes + the s value.
  Future<CaptchaResult> getCaptcha() async {
    final s = _randS();
    final r = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$_baseUrl/api/v1/captcha/?s=$s&r=$r');
    final resp = await _client.get(url, headers: {
      'User-Agent':
          'Dalvik/2.1.0 (Linux; U; Android 16; PHP110 Build/BP2A.250605.015)',
    });
    return CaptchaResult(
      s: s,
      r: r,
      imageBytes: resp.bodyBytes,
      contentType: resp.headers['content-type'] ?? 'image/png',
    );
  }

  /// Step 1: Request SMS verification code.
  Future<ApiResponse> sendSmsCode({
    required String phone,
    required String captchaCode,
    required double captchaS,
  }) async {
    final resp = await _post('/api/v1/acc/login/code', data: {
      'authCode': captchaCode,
      's': captchaS,
      'un': phone,
    });
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Step 2: Login with SMS code.
  Future<ApiResponse> login({
    required String phone,
    required String smsCode,
  }) async {
    final resp = await _post('/api/v1/acc/login', data: {
      'authCode': smsCode,
      'un': phone,
    });
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = ApiResponse.fromJson(json);
    if (result.code == 0 && json['data'] != null) {
      final al = json['data']['al'];
      if (al != null) {
        _token = al['token'] as String?;
        _uid = al['uid'] as String?;
        _eid = al['eid'] as String?;
        await _persistToken();
      }
    }
    return result;
  }

  /// Get master app data (device list, account info, etc.)
  Future<ApiResponse> getMaster() async {
    final resp = await _get('/api/v1/ui/app/master');
    final result = ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    if (result.isSuccess && result.data != null) {
      _cacheMaster(resp.body);
    }
    return result;
  }

  /// Try to load cached master data for instant display.
  Future<Map<String, dynamic>?> loadCachedMaster() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_master');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['code'] == 0 && json['data'] != null) {
        return json['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheMaster(String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_master', body);
  }

  /// Get QR / device usage info.
  Future<ApiResponse> getDeviceQr(String deviceId) async {
    final resp = await _get('/api/v1/qr/use?id=$deviceId');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get device home page data.
  Future<ApiResponse> getDeviceHome(String deviceId, {int apply = 6}) async {
    final resp =
        await _get('/api/v1/ui/app/dev/home/1?did=$deviceId&apply=$apply');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get device status.
  Future<ApiResponse> getDeviceStatus(String deviceId) async {
    final resp =
        await _get('/api/v1/ui/app/dev/status?did=$deviceId&more=false');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Start device (begin water flow).
  Future<ApiResponse> startDevice(String deviceId, {int ptype = 21}) async {
    final resp = await _get(
      '/api/v1/dev/start?did=$deviceId&upgrade=true&ptype=$ptype&args=&rcp=false&cnt=1',
    );
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Stop device (end water flow).
  Future<ApiResponse> stopDevice(String deviceId) async {
    final resp = await _get('/api/v1/dev/end?did=$deviceId&rcp=false');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get full account info.
  Future<ApiResponse> getAccount() async {
    final resp = await _get('/api/v1/acc/');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get score mission list (tasks to earn points).
  /// Returns server time in response.time — capture it for sign generation.
  Future<ApiResponse> getMissionList() async {
    final resp = await _get('/api/v1/acc/score/mission-lst');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Claim points by completing a task.
  /// [sign] — MD5 sign generated by SignUtils.generateScoreSign()
  Future<ApiResponse> sendScore({
    required String adId,
    required int score,
    required String sign,
    int addScoreType = 1,
  }) async {
    final resp = await _post('/api/v1/acc/score/score-send?sign=$sign&s=1', data: {
      'adId': adId,
      'type': 101,
      'addScoreType': addScoreType,
      'addScore': score,
      'token': _token ?? '',
    });
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get score history (points earned/spent).
  Future<ApiResponse> getScoreList({int page = 1, int size = 20}) async {
    final resp = await _get('/api/v1/acc/score/score-lst?page=$page&size=$size&hasCount=true&src=0');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Get bill/consumption list.
  Future<ApiResponse> getBillList({int page = 1, int size = 20}) async {
    final resp = await _get('/api/v1/bill/lst-owner?page=$page&size=$size&hasCount=true&status=0');
    return ApiResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get uid => _uid;
  String? get eid => _eid;

  /// Persist token to local storage so login survives app restart.
  Future<void> _persistToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_keyToken, _token!);
      await prefs.setString(_keyUid, _uid ?? '');
      await prefs.setString(_keyEid, _eid ?? '');
    }
  }

  /// Try to restore a previously saved token. Returns true if found.
  Future<bool> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_keyToken);
    if (t != null && t.isNotEmpty) {
      _token = t;
      _uid = prefs.getString(_keyUid);
      _eid = prefs.getString(_keyEid);
      return true;
    }
    return false;
  }

  /// Clear saved token (logout).
  Future<void> clearToken() async {
    _token = null;
    _uid = null;
    _eid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUid);
    await prefs.remove(_keyEid);
  }

  Future<http.Response> _get(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    return _client.get(url, headers: _authHeaders);
  }

  Future<http.Response> _post(String path,
      {required Map<String, dynamic> data}) async {
    final url = Uri.parse('$_baseUrl$path');
    return _client.post(
      url,
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );
  }

  void dispose() {
    _client.close();
  }
}

class CaptchaResult {
  final double s;
  final int r;
  final List<int> imageBytes;
  final String contentType;

  CaptchaResult({
    required this.s,
    required this.r,
    required this.imageBytes,
    required this.contentType,
  });
}

class ApiResponse {
  final int code;
  final Map<String, dynamic>? data;
  final int? time;

  ApiResponse({required this.code, this.data, this.time});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      code: json['code'] as int? ?? -1,
      data: json['data'] as Map<String, dynamic>?,
      time: json['time'] as int?,
    );
  }

  bool get isSuccess => code == 0;
}
