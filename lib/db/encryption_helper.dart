import 'dart:convert';

/// Very small demonstration encryption helper. THIS IS NOT PRODUCTION-GRADE.
/// For real apps use a proper crypto library (flutter_secure_storage + cryptography or sqlite encryption plugin).
class EncryptionHelper {
  // Simple XOR obfuscation with a key (for demo only)
  static String _xor(String input, String key) {
    final inBytes = utf8.encode(input);
    final keyBytes = utf8.encode(key);
    final out = List<int>.generate(inBytes.length, (i) => inBytes[i] ^ keyBytes[i % keyBytes.length]);
    return base64.encode(out);
  }

  static String encrypt(String plain, String key) {
    return _xor(plain, key);
  }

  static String decrypt(String cipher, String key) {
    try {
      final data = base64.decode(cipher);
      final keyBytes = utf8.encode(key);
      final out = List<int>.generate(data.length, (i) => data[i] ^ keyBytes[i % keyBytes.length]);
      return utf8.decode(out);
    } catch (_) {
      return cipher; // if failed, return raw
    }
  }
}
