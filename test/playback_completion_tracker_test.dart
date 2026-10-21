import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/playback_completion_tracker.dart';

void main() {
  test(
      'route stop and restart never advance; explicit completion advances once',
      () {
    final tracker = PlaybackCompletionTracker();
    expect(
        tracker.update(isPlaying: true, isPaused: false, hasCompleted: false),
        isFalse);
    for (var tick = 0; tick < 20; tick++) {
      expect(
          tracker.update(
              isPlaying: false, isPaused: false, hasCompleted: false),
          isFalse);
    }
    expect(
        tracker.update(isPlaying: true, isPaused: false, hasCompleted: false),
        isFalse);
    expect(
        tracker.update(isPlaying: false, isPaused: false, hasCompleted: true),
        isTrue);
    expect(
        tracker.update(isPlaying: false, isPaused: false, hasCompleted: true),
        isFalse);
  });

  test('pause and playing snapshots cannot count as completion', () {
    final tracker = PlaybackCompletionTracker();
    expect(tracker.update(isPlaying: true, isPaused: false, hasCompleted: true),
        isFalse);
    expect(tracker.update(isPlaying: false, isPaused: true, hasCompleted: true),
        isFalse);
    expect(
        tracker.update(isPlaying: false, isPaused: false, hasCompleted: true),
        isTrue);
  });

  test('reset discards stale completion after stop, seek or track replacement',
      () {
    final tracker = PlaybackCompletionTracker();
    tracker.update(isPlaying: true, isPaused: false, hasCompleted: false);
    tracker.reset();
    expect(
        tracker.update(isPlaying: false, isPaused: false, hasCompleted: true),
        isFalse);
    tracker.update(isPlaying: true, isPaused: false, hasCompleted: false);
    expect(
        tracker.update(isPlaying: false, isPaused: false, hasCompleted: true),
        isTrue);
  });
}
