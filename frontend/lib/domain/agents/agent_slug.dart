/// Validation and suggestion helpers for cross-platform safe agent slugs.
abstract final class AgentSlug {
  static final RegExp _validPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');
  static final RegExp _nonSlugChars = RegExp('[^a-z0-9_-]+');
  static final RegExp _multiHyphen = RegExp('-{2,}');
  static final RegExp _edgeTrim = RegExp(r'^[-_]+|[-_]+$');

  static const Set<String> _reservedOsNames = <String>{
    'con',
    'prn',
    'aux',
    'nul',
    'com1',
    'com2',
    'com3',
    'com4',
    'com5',
    'com6',
    'com7',
    'com8',
    'com9',
    'lpt1',
    'lpt2',
    'lpt3',
    'lpt4',
    'lpt5',
    'lpt6',
    'lpt7',
    'lpt8',
    'lpt9',
  };

  /// Suggests a cross-platform safe lowercase slug from a human [name].
  static String suggest(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return '';
    final replaced = lower
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(_nonSlugChars, '-')
        .replaceAll(_multiHyphen, '-')
        .replaceAll(_edgeTrim, '');
    if (replaced.isEmpty) return '';
    if (_reservedOsNames.contains(replaced)) {
      return '$replaced-agent';
    }
    return replaced;
  }

  /// Returns `true` when [slug] is a valid cross-platform agent filename id.
  static bool isValid(String slug) {
    if (slug.isEmpty || slug.length > 64) return false;
    if (!_validPattern.hasMatch(slug)) return false;
    if (_reservedOsNames.contains(slug)) return false;
    return true;
  }
}
