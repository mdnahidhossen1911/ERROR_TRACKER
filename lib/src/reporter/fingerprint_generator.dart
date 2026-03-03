import 'dart:convert';

/// Generates a stable fingerprint for an error so that identical crashes
/// are grouped together — exactly like Firebase Crashlytics issue grouping.
///
/// The fingerprint is built from:
///   1. The top N frames of the stack trace (normalized)
///   2. The error message class (not the full message, to avoid noise
///      from dynamic values like IDs in messages)
///
/// Two crashes with the same root cause will always produce the
/// same fingerprint regardless of the specific values involved.
class FingerprintGenerator {
  static const int _maxFrames = 5;

  /// Returns a short hex fingerprint string (12 chars).
  static String generate({
    required String message,
    StackTrace? stackTrace,
  }) {
    final normalized = _normalize(message, stackTrace);
    return _shortHash(normalized);
  }

  static String _normalize(String message, StackTrace? stackTrace) {
    // Extract the error class from the message.
    // e.g. "FormatException: bad input" → "FormatException"
    final errorClass = message.split(':').first.trim();

    final frames = _topFrames(stackTrace);
    return '$errorClass|${frames.join('|')}';
  }

  static List<String> _topFrames(StackTrace? stackTrace) {
    if (stackTrace == null) return [];
    return stackTrace
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(_maxFrames)
        // Strip line numbers so refactors don't change the fingerprint.
        .map((l) => l.replaceAll(RegExp(r':\d+:\d+'), ''))
        .toList();
  }

  static String _shortHash(String input) {
    // Simple djb2-style hash, no external crypto dependency.
    var hash = 5381;
    for (final unit in utf8.encode(input)) {
      hash = ((hash << 5) + hash) ^ unit;
      hash &= 0xFFFFFFFFFFFF; // keep 48 bits
    }
    return hash.toRadixString(16).padLeft(12, '0').substring(0, 12);
  }
}
