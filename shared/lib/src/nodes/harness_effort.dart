/// Effort levels shared by all harnesses (glossary: **Effort**).
enum HarnessEffort {
  /// Low reasoning effort.
  low,

  /// Medium reasoning effort.
  medium,

  /// High reasoning effort.
  high,

  /// Maximum reasoning effort.
  max;

  /// Returns the level named [value], or `null` when [value] is not one.
  static HarnessEffort? tryParse(String? value) =>
      values.asNameMap()[value?.trim()];
}

/// Accepted `effort` values as serialized in JSON.
const Set<String> harnessEffortIds = {'low', 'medium', 'high', 'max'};
