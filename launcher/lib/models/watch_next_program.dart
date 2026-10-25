class WatchNextProgram {
  final int id;
  final String packageName;
  final String title;
  final String description;
  final int watchNextType;
  final int lastEngagementTime;
  final int playbackPosition;
  final int duration;
  final String intentUri;
  final String posterArtUri;

  WatchNextProgram({
    required this.id,
    required this.packageName,
    required this.title,
    required this.description,
    required this.watchNextType,
    required this.lastEngagementTime,
    required this.playbackPosition,
    required this.duration,
    required this.intentUri,
    required this.posterArtUri,
  });

  factory WatchNextProgram.fromMap(Map<dynamic, dynamic> map) {
    return WatchNextProgram(
      id: (map['id'] as num?)?.toInt() ?? 0,
      packageName: map['packageName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      watchNextType: (map['watchNextType'] as num?)?.toInt() ?? 0,
      lastEngagementTime: (map['lastEngagementTime'] as num?)?.toInt() ?? 0,
      playbackPosition: (map['playbackPosition'] as num?)?.toInt() ?? 0,
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      intentUri: map['intentUri'] as String? ?? '',
      posterArtUri: map['posterArtUri'] as String? ?? '',
    );
  }

  /// Returns normalized playback progress between 0.0 and 1.0,
  /// safely guarding against divide-by-zero, negative values, NaN, and infinity.
  double get safeProgress {
    if (duration <= 0 || playbackPosition <= 0) return 0.0;
    final value = playbackPosition / duration;
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 1.0);
  }
}
