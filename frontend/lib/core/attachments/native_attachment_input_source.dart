import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/attachments/attachment_input_source.dart';
import 'package:agentic_hive_frontend/domain/runs/run_attachment_drafts.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as na;
import 'package:path/path.dart' as p;

/// Decodes a base64 string (raw or `data:<mime>;base64,...`) returned by
/// `na.Image.toBase64()`.
@visibleForTesting
Uint8List? decodeClipboardImageBase64(String? value) {
  if (value == null || value.isEmpty) return null;
  var payload = value.trim();
  if (payload.startsWith('data:')) {
    final commaIndex = payload.indexOf(',');
    if (commaIndex == -1) return null;
    final header = payload.substring(0, commaIndex).toLowerCase();
    if (!header.contains(';base64')) return null;
    payload = payload.substring(commaIndex + 1);
  }
  if (payload.isEmpty) return null;
  try {
    return base64Decode(payload);
  } on FormatException {
    return null;
  }
}

/// `nativeapi`-backed [AttachmentInputSource] for Windows, Linux, and macOS.
final class NativeAttachmentInputSource implements AttachmentInputSource {
  late final StreamController<AttachmentDropEvent> _controller =
      StreamController<AttachmentDropEvent>.broadcast(
        onListen: _ensureDropTarget,
      );

  na.DropTarget? _dropTarget;
  na.ListenerId? _listenerId;
  bool _dropInitAttempted = false;
  bool _disposed = false;

  @override
  Future<Uint8List?> readClipboardImage() async {
    if (_disposed) return null;
    na.Image? image;
    try {
      if (!na.Clipboard.instance.isSupported()) return null;
      image = await na.Clipboard.instance.readImageAsync();
      return decodeClipboardImageBase64(image?.toBase64());
    } on Object {
      return null;
    } finally {
      image?.dispose();
    }
  }

  @override
  Stream<AttachmentDropEvent> get drops => _controller.stream;

  void _ensureDropTarget() {
    if (_disposed || _dropTarget != null || _dropInitAttempted) return;
    _dropInitAttempted = true;
    try {
      if (!na.DropTarget.isSupported()) return;
      final window = na.WindowManager.instance.getCurrent();
      final target = na.DropTarget.create(window);
      if (target == null) return;
      _dropTarget = target;
      _listenerId = target.addListener(_onDropEvent);
    } on Object {
      // Native drop target unavailable (e.g. headless environment).
    }
  }

  void _onDropEvent(na.DropTargetEvent event) {
    if (_disposed || _controller.isClosed) return;
    switch (event) {
      case na.DropTargetEnteredEvent():
        _controller.add(AttachmentDragEntered());
      case na.DropTargetExitedEvent():
        _controller.add(AttachmentDragExited());
      case na.DropTargetDroppedEvent(:final filePaths):
        unawaited(_handleDropped(filePaths));
      case na.DropTargetMovedEvent():
        break;
    }
  }

  Future<void> _handleDropped(List<String> filePaths) async {
    final candidates = <RunAttachmentCandidate>[];
    for (final path in filePaths) {
      final fileName = p.basename(path);
      try {
        final file = File(path);
        final sizeBytes = await file.length();
        final bytes = sizeBytes <= RunAttachmentLimits.maxBytesEach
            ? await file.readAsBytes()
            : null;
        candidates.add(
          RunAttachmentCandidate(
            fileName: fileName,
            sizeBytes: sizeBytes,
            bytes: bytes,
          ),
        );
      } on Object {
        candidates.add(
          RunAttachmentCandidate(fileName: fileName, sizeBytes: 0, bytes: null),
        );
      }
    }
    if (_disposed || _controller.isClosed) return;
    _controller.add(AttachmentFilesDropped(candidates));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final listenerId = _listenerId;
    _listenerId = null;
    if (listenerId != null) {
      _dropTarget?.removeListener(listenerId);
    }
    _dropTarget?.dispose();
    _dropTarget = null;
    await _controller.close();
  }
}
