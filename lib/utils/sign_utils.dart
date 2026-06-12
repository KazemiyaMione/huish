import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class SignUtils {
  static const _salt = 'aslkdvcniu34h9tgufh278wv2';

  /// Generate MD5 sign for score-send API.
  ///
  /// [adId] — task refId from mission list
  /// [token] — full login JWT
  /// [uid] — full user ID (16 hex chars)
  /// [localTs] — milliseconds timestamp recorded when fetching mission list
  /// [serverTs] — server milliseconds timestamp from mission list response (BaseReq.time)
  static String generateScoreSign({
    required String adId,
    required String token,
    required String uid,
    required int localTs,
    required int serverTs,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final v20 = 10 * ((serverTs - localTs + nowMs) ~/ 10000);
    final raw =
        '$adId$v20${token.substring(token.length - 8)}${uid.substring(uid.length - 8)}$_salt';
    return crypto.md5.convert(utf8.encode(raw)).toString();
  }
}
