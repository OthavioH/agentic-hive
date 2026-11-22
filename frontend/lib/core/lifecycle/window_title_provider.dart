import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'window_title_provider.g.dart';

/// Callback that applies the localized application title to the OS window.
typedef WindowTitleSetter = void Function(String title);

/// Provides the platform callback that updates the native window title.
///
/// Tests can override this provider to observe title updates without requiring
/// a loaded `nativeapi` dynamic library.
@Riverpod(keepAlive: true)
WindowTitleSetter windowTitleSetter(Ref ref) => (title) {
  try {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.title = title;
    }
  } on Object catch (_) {
    // Running in a headless test VM without the nativeapi dynamic library.
  }
};
