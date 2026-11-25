/// Reads the spec number from an Agentic Hive prompt: the first number in its
/// `## Run input` section (`100`, `#100` and `Spec #100` all work). Returns
/// null when the section or the number is missing.
int? specNumberFromPrompt(String prompt) {
  final section = RegExp(
    r'^## Run input\s*\n([\s\S]*?)(?=^## |(?![\s\S]))',
    multiLine: true,
  ).firstMatch(prompt);
  if (section == null) return null;
  final number = RegExp(r'\d+').firstMatch(section.group(1)!);
  return number == null ? null : int.parse(number.group(0)!);
}
