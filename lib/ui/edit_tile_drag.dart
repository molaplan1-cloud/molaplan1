/// Edit-mode tile dragging: mouse/trackpad starts on press-and-move,
/// touch still needs a long-press so the dashboard can scroll (R420 / t301u).
///
/// On the web, [Plat.isWindows]/[Plat.isLinux]/[Plat.isMacOS] are always false,
/// so a platform check would pick [LongPressDraggable] in desktop Chrome and a
/// mouse drag would never start. The recognizer therefore keys off the pointer
/// kind, not the OS.
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Pointers that should start a tile drag after a short movement, no long-press.
bool isImmediateEditDragPointer(PointerDeviceKind kind) => switch (kind) {
  PointerDeviceKind.mouse ||
  PointerDeviceKind.trackpad ||
  PointerDeviceKind.stylus ||
  PointerDeviceKind.invertedStylus => true,
  PointerDeviceKind.touch || PointerDeviceKind.unknown => false,
};

/// [Draggable] that uses [isImmediateEditDragPointer] to pick the recognizer.
class EditTileDraggable<T extends Object> extends Draggable<T> {
  const EditTileDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.onDragStarted,
    super.onDragEnd,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return _EditTileDragRecognizer(debugOwner: this)..onStart = onStart;
  }
}

class _EditTileDragRecognizer extends MultiDragGestureRecognizer {
  _EditTileDragRecognizer({super.debugOwner});

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    if (isImmediateEditDragPointer(event.kind)) {
      return _ImmediatePointerState(
        event.position,
        event.kind,
        gestureSettings,
      );
    }
    return _DelayedPointerState(
      event.position,
      kLongPressTimeout,
      event.kind,
      gestureSettings,
    );
  }

  @override
  String get debugDescription => 'edit tile drag';
}

class _ImmediatePointerState extends MultiDragPointerState {
  _ImmediatePointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
  );

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class _DelayedPointerState extends MultiDragPointerState {
  _DelayedPointerState(
    super.initialPosition,
    Duration delay,
    super.kind,
    super.gestureSettings,
  ) {
    _timer = Timer(delay, _delayPassed);
  }

  Timer? _timer;
  GestureMultiDragStartCallback? _starter;

  void _delayPassed() {
    _timer = null;
    if (_starter != null) {
      _starter!(initialPosition);
      _starter = null;
    } else {
      resolve(GestureDisposition.accepted);
    }
  }

  void _ensureTimerStopped() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    if (_timer == null) {
      starter(initialPosition);
    } else {
      _starter = starter;
    }
  }

  @override
  void checkForResolutionAfterMove() {
    if (_timer == null) return;
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.rejected);
      _ensureTimerStopped();
    }
  }

  @override
  void dispose() {
    _ensureTimerStopped();
    super.dispose();
  }
}
