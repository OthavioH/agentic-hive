/// Default per-stream character cap for `stdout` and `stderr` stored in
/// non-contract node outcomes (`CommandNode`, `TestsValidatorNode`).
const int maxNodeOutputStreamChars = 16384;

/// Returns [output] unchanged when its length is within [maxChars], or keeps
/// the trailing [maxChars] characters with a leading truncation notice
/// pointing to the node's run logs.
String truncateOutputTail(
  String output, {
  int maxChars = maxNodeOutputStreamChars,
}) {
  if (output.length <= maxChars) return output;
  final omitted = output.length - maxChars;
  final tail = output.substring(omitted);
  return '[... truncated $omitted leading characters; '
      'see node run logs for full output ...]\n$tail';
}
