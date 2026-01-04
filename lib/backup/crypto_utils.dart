import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _iterations = 100000;
  static const int _keyLength = 32; // 256 bits

  // Generate secure random bytes
  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  // PBKDF2-HMAC-SHA256 (manual implementation)
  static Uint8List _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, password.codeUnits);
    final blockCount = (length / 32).ceil();
    final output = <int>[];

    for (var block = 1; block <= blockCount; block++) {
      var u = hmac.convert(Uint8List.fromList([...salt, 0, 0, 0, block])).bytes;

      var t = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }

      output.addAll(t);
    }

    return Uint8List.fromList(output.sublist(0, length));
  }

  // Encrypt raw bytes using AES-256-CBC
  static Uint8List encryptBytes(Uint8List plainBytes, String password) {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final keyBytes = _pbkdf2(password, salt, _iterations, _keyLength);

    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(plainBytes, iv: enc.IV(iv));

    // Final format:
    // [salt][iv][cipherText]
    return Uint8List.fromList([...salt, ...iv, ...encrypted.bytes]);
  }

  // Decrypt raw bytes
  static Uint8List decryptBytes(Uint8List encryptedBytes, String password) {
    if (encryptedBytes.length < (_saltLength + _ivLength)) {
      throw Exception("Invalid encrypted data");
    }

    final salt = encryptedBytes.sublist(0, _saltLength);
    final iv = encryptedBytes.sublist(_saltLength, _saltLength + _ivLength);
    final cipherText = encryptedBytes.sublist(_saltLength + _ivLength);

    final keyBytes = _pbkdf2(password, salt, _iterations, _keyLength);

    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    try {
      return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(cipherText), iv: enc.IV(iv)),
      );
    } catch (_) {
      throw Exception("Wrong password or corrupted backup");
    }
  }
}
