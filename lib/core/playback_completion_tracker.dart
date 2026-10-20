/// Tracks natural completion across temporary output stops and route rebuilds.
class PlaybackCompletionTracker {
  bool _hasPlayed = false;

  void reset() => _hasPlayed = false;

  bool update({
    required bool isPlaying,
    required bool isPaused,
    required bool hasCompleted,
  }) {
    if (isPlaying) {
      _hasPlayed = true;
      return false;
    }
    if (!_hasPlayed || isPaused || !hasCompleted) return false;
    _hasPlayed = false;
    return true;
  }
}
