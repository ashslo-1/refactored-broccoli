enum TvInputType {
  tuner,
  hdmi,
  av,
  other
}

class TvInput {
  final String id;
  final String label;
  final TvInputType type;

  TvInput({
    required this.id,
    required this.label,
    required this.type,
  });

  factory TvInput.fromMap(Map<dynamic, dynamic> map) {
    final int typeInt = map['type'] as int? ?? 1000;
    TvInputType type;
    if (typeInt == 1007) {
      type = TvInputType.hdmi;
    } else if (typeInt == 0 || typeInt == 2 || typeInt == 3) {
      type = TvInputType.tuner;
    } else if (typeInt >= 1001 && typeInt <= 1004) {
      type = TvInputType.av;
    } else {
      type = TvInputType.other;
    }

    return TvInput(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      type: type,
    );
  }
}
