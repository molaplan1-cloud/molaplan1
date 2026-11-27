/// AES-128-CBC with PKCS#7 padding on top of the in-house AES block cipher (lib/tuya/aes.dart).
/// Used by Sonoff eWeLink LAN encrypted mode and Philips JointSPACE encrypted system fields.
library;

import 'dart:math';
import 'dart:typed_data';

import '../tuya/aes.dart';

Uint8List aesCbcEncrypt(List<int> key, List<int> iv, List<int> data) {
  if (iv.length != 16) throw ArgumentError('AES-CBC: IV must be 16 bytes');
  final a = Aes128(key);
  final n = 16 - data.length % 16;
  final d = [...data, for (var i = 0; i < n; i++) n];
  final out = BytesBuilder(copy: false);
  var prev = List<int>.from(iv);
  for (var i = 0; i < d.length; i += 16) {
    final blk = [for (var j = 0; j < 16; j++) d[i + j] ^ prev[j]];
    final c = a.encryptBlock(blk);
    out.add(c);
    prev = c;
  }
  return out.toBytes();
}

Uint8List aesCbcDecrypt(List<int> key, List<int> iv, List<int> data) {
  if (iv.length != 16) throw ArgumentError('AES-CBC: IV must be 16 bytes');
  if (data.isEmpty || data.length % 16 != 0) throw const FormatException('AES-CBC: not whole blocks');
  final a = Aes128(key);
  final out = BytesBuilder(copy: false);
  var prev = iv;
  for (var i = 0; i < data.length; i += 16) {
    final p = a.decryptBlock(data, i);
    out.add([for (var j = 0; j < 16; j++) p[j] ^ prev[j]]);
    prev = data.sublist(i, i + 16);
  }
  final b = out.toBytes();
  final n = b.last;
  if (n < 1 || n > 16 || n > b.length) throw const FormatException('AES-CBC: bad padding');
  for (var i = b.length - n; i < b.length; i++) {
    if (b[i] != n) throw const FormatException('AES-CBC: bad padding');
  }
  return Uint8List.sublistView(b, 0, b.length - n);
}

Uint8List randomIv() {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
}
