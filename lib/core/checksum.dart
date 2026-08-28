// lib/core/checksum.dart
//
// Helper de checksum para uploads content-addressed.
// O cliente calcula o SHA-256 do arquivo e envia no campo `checksum`;
// o backend usa esse hash para nomear/deduplicar o blob sem re-hashear no hot path.
import 'package:crypto/crypto.dart';

/// SHA-256 hex (64 chars, minúsculo) dos bytes informados.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
