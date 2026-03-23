/// Lightweight client-side profanity check for user-submitted text.
///
/// Uses a curated word list. Returns `true` when the text contains a
/// blocked word (case-insensitive, whole-word match).
class ProfanityFilter {
  ProfanityFilter._();

  // Common profanity terms (whole-word matched, case-insensitive).
  // Kept intentionally short — extend as needed.
  static final _blocked = RegExp(
    r'\b('
    'shit|fuck|fuckin|fucking|fucker|bitch|bastard|asshole|'
    'damn|dick|cunt|piss|cock|whore|slut|'
    'nigger|nigga|fag|faggot|retard|retarded'
    r')\b',
    caseSensitive: false,
  );

  /// Returns the first matched profanity word, or `null` if clean.
  static String? check(String text) {
    final match = _blocked.firstMatch(text);
    return match?.group(0);
  }

  /// Returns `true` when [text] contains blocked language.
  static bool containsProfanity(String text) => _blocked.hasMatch(text);
}
