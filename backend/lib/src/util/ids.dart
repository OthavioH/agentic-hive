import 'dart:math';

final _random = Random.secure();

/// A random 128-bit id as 32 lowercase hex characters.
String randomId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
