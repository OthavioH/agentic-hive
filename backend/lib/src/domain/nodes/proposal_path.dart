/// Resolves a dot-separated path inside decoded JSON data.
abstract final class ProposalPath {
  /// Value at [path] inside [data], or null when any segment is missing.
  static Object? resolve(Object? data, String path) {
    var current = data;
    for (final segment in path.split('.')) {
      if (current == null) return null;
      if (current is Map) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }
}
