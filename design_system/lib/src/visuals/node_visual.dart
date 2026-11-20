import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:material_ui/material_ui.dart';

/// How a node type looks: its icon, its localized label key and an optional
/// accent role.
///
/// Each node type registers one [NodeVisual] in a [NodeVisualRegistry]. The
/// UI resolves visuals through the registry and never switches on node type.
@immutable
class NodeVisual {
  /// Creates a visual.
  const new({required this.icon, required this.labelKey, this.accent});

  /// The default visual for unregistered node types: the Hive robot.
  static const NodeVisual fallback = NodeVisual(
    icon: HiveIcons.robot,
    labelKey: 'nodeTypeUnknown',
  );

  /// The face of the node: a harness logo, the robot or a kind icon.
  final HiveIconData icon;

  /// Localization key of the node type's display name.
  final String labelKey;

  /// Optional color role for the icon; `onSurface` when null.
  final HiveColorRole? accent;
}

/// Maps node type ids to their [NodeVisual].
///
/// Registration happens once at startup, next to each node type; lookups of
/// an unknown type return [fallback].
class NodeVisualRegistry {
  /// Creates an empty registry.
  new({this.fallback = NodeVisual.fallback});

  /// Visual returned for node types that did not register.
  final NodeVisual fallback;

  final Map<String, NodeVisual> _visuals = <String, NodeVisual>{};

  /// Registers [visual] for [nodeType].
  ///
  /// Throws a [StateError] when [nodeType] is already registered, so two
  /// node types cannot silently fight over one id.
  void register(String nodeType, NodeVisual visual) {
    if (_visuals.containsKey(nodeType)) {
      throw StateError('Node type "$nodeType" already has a visual.');
    }
    _visuals[nodeType] = visual;
  }

  /// The visual of [nodeType], or [fallback].
  NodeVisual resolve(String nodeType) => _visuals[nodeType] ?? fallback;

  /// Whether [nodeType] registered a visual.
  bool contains(String nodeType) => _visuals.containsKey(nodeType);

  /// Every registered visual by node type id.
  Map<String, NodeVisual> get entries => Map.unmodifiable(_visuals);
}

/// Provides a [NodeVisualRegistry] to the widget tree.
class NodeVisualScope extends InheritedWidget {
  /// Creates a scope for [registry].
  const new({required this.registry, required super.child, super.key});

  /// The registry below this widget.
  final NodeVisualRegistry registry;

  /// The nearest registry. Throws when no [NodeVisualScope] is above.
  static NodeVisualRegistry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NodeVisualScope>();
    assert(scope != null, 'No NodeVisualScope found in context.');
    return scope!.registry;
  }

  @override
  bool updateShouldNotify(NodeVisualScope oldWidget) {
    return !identical(oldWidget.registry, registry);
  }
}
