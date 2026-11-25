import 'dart:async';
import 'dart:typed_data';

import 'package:agentic_hive_frontend/core/attachments/native_attachment_input_source.dart';
import 'package:agentic_hive_frontend/domain/runs/run_attachment_drafts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attachment_input_source.g.dart';

/// Events emitted by an [AttachmentInputSource] for native file drag-and-drop.
sealed class AttachmentDropEvent;

/// A native file drag entered the application window.
final class AttachmentDragEntered extends AttachmentDropEvent;

/// A native file drag exited the application window without dropping.
final class AttachmentDragExited extends AttachmentDropEvent;

/// One or more files were dropped onto the application window.
final class AttachmentFilesDropped extends AttachmentDropEvent {
  /// Creates an [AttachmentFilesDropped] event.
  new(this.files);

  /// Candidates read from the dropped file paths.
  final List<RunAttachmentCandidate> files;
}

/// OS-abstracted source for clipboard image reads and native file drops
/// (ADR 0012).
abstract interface class AttachmentInputSource {
  /// Image bytes on the clipboard, or `null` when there is none or the
  /// platform cannot read clipboard images.
  Future<Uint8List?> readClipboardImage();

  /// Broadcast stream of native drag-and-drop events.
  Stream<AttachmentDropEvent> get drops;

  /// Releases native listeners and closes the stream.
  Future<void> dispose();
}

/// Provides the app-wide [AttachmentInputSource].
@Riverpod(keepAlive: true)
AttachmentInputSource attachmentInputSource(Ref ref) {
  final source = NativeAttachmentInputSource();
  ref.onDispose(() => unawaited(source.dispose()));
  return source;
}
