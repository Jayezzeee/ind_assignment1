import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _keyAlias = 'encryption_key';

  Future<encrypt.Key> _getKey() async {
    String? keyString = await _secureStorage.read(key: _keyAlias);
    if (keyString == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      await _secureStorage.write(key: _keyAlias, value: base64Encode(key.bytes));
      return key;
    }
    return encrypt.Key(base64Decode(keyString));
  }

  Future<String> encryptData(String plainText) async {
    final key = await _getKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Prepend IV to encrypted data
    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }

  Future<String> decryptData(String encryptedText) async {
    try {
      final key = await _getKey();
      final combined = base64Decode(encryptedText);
      final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encryptedBytes = Uint8List.fromList(combined.sublist(16));
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      // If decryption fails, assume it's plain text (backward compatibility)
      return encryptedText;
    }
  }
}