import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PinCrypto {
  static String generateSalt([int byteLength = 16]) {
    final rng = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin$salt');
    return sha256.convert(bytes).toString();
  }

  static bool verifyPin(String inputPin, String? storedHash, String? storedSalt) {
    if (storedHash == null ||
        storedHash.isEmpty ||
        storedSalt == null ||
        storedSalt.isEmpty) {
      return false;
    }
    return hashPin(inputPin, storedSalt) == storedHash;
  }

  static bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }
}
