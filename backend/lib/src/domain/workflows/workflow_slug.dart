const _maxSlugLength = 64;

/// Turns a workflow [name] into a lowercase file-safe slug.
///
/// Runs of characters outside `a-z0-9` collapse to one hyphen; a name with no
/// usable character yields `workflow`.
String slugifyWorkflowName(String name) {
  final collapsed = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (collapsed.isEmpty) return 'workflow';
  return collapsed.length <= _maxSlugLength
      ? collapsed
      : collapsed.substring(0, _maxSlugLength).replaceAll(RegExp(r'-+$'), '');
}
