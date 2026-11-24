/// Patch operation names of `edit_workflow`; they are operations, not tools.
const editWorkflowOperationNames = <String>{
  'add_node',
  'update_node',
  'remove_node',
  'connect',
  'disconnect',
  'set_entry',
  'set_meta',
};

final _frontmatterPattern = RegExp(r'^---\r?\n[\s\S]*?\r?\n---\r?\n');

final _snakeCaseTokenPattern = RegExp('`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`');

/// Backticked snake_case tokens in [markdown] (frontmatter stripped), minus
/// [editWorkflowOperationNames].
Set<String> workflowToolNamesIn(String markdown) {
  final body = markdown.replaceFirst(_frontmatterPattern, '');
  return {
    for (final match in _snakeCaseTokenPattern.allMatches(body))
      if (!editWorkflowOperationNames.contains(match.group(1))) match.group(1)!,
  };
}
