class Setting {
  final int? id;
  final String? settingsKey;
  final String? settingsValue;

  const Setting({
    this.id,
    required this.settingsKey,
    required this.settingsValue,
  });

  Setting copyWith({
    int? id,
    String? settingsKey,
    String? settingsValue,
  }) {
    return Setting(
      id: id ?? this.id,
      settingsKey: settingsKey ?? this.settingsKey,
      settingsValue: settingsValue ?? this.settingsValue,
    );
  }

  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
      id: map['id'] == null
          ? null
          : (map['id'] is int ? map['id'] : int.tryParse(map['id'].toString())),
      settingsKey: map['settingsKey']?.toString() ?? '',
      settingsValue: map['settingsValue']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'settingsKey': settingsKey,
      'settingsValue': settingsValue,
    };
  }
}