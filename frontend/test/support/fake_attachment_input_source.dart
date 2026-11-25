import 'dart:async';
import 'dart:typed_data';

import 'package:agentic_hive_frontend/core/attachments/attachment_input_source.dart';

/// In-memory [AttachmentInputSource] fake for widget tests.
final class FakeAttachmentInputSource implements AttachmentInputSource {
  final StreamController<AttachmentDropEvent> _controller =
      StreamController<AttachmentDropEvent>.broadcast();

  /// Image bytes returned by [readClipboardImage].
  Uint8List? clipboardImage;

  /// Emits [event] onto [drops].
  void emit(AttachmentDropEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  @override
  Future<Uint8List?> readClipboardImage() async => clipboardImage;

  @override
  Stream<AttachmentDropEvent> get drops => _controller.stream;

  @override
  Future<void> dispose() => _controller.close();
}
