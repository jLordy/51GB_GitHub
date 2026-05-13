import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// The prefix written to Firestore by the backend for every encrypted message.
const _kPrefix = 'enc:';

/// Decrypt [text] if it carries the 'enc:' prefix; otherwise return it as-is.
///
/// [base64Key] must be the base64-encoded 32-byte AES-256 key obtained from
/// `GET /api/chat/key`.
String tryDecryptMessage(String text, String base64Key) {
  if (!text.startsWith(_kPrefix)) return text; // legacy plaintext

  final blob = base64.decode(text.substring(_kPrefix.length));

  // Layout: nonce[12 bytes] | ciphertext_with_auth_tag
  final nonce = Uint8List.fromList(blob.sublist(0, 12));
  final cipherBytes = Uint8List.fromList(blob.sublist(12));

  final keyBytes = base64.decode(base64Key);
  final key = Key(keyBytes);
  final iv = IV(nonce);

  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  final encrypted = Encrypted(cipherBytes);
  return encrypter.decrypt(encrypted, iv: iv);
}
