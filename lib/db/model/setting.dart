class SettingModel {
  final int? id;
  final String? settingsKey;
  final String? settingsValue;

  const SettingModel({
    this.id,
    required this.settingsKey,
    required this.settingsValue,
  });

  SettingModel copyWith({
    int? id,
    String? settingsKey,
    String? settingsValue,
  }) {
    return SettingModel(
      id: id ?? this.id,
      settingsKey: settingsKey ?? this.settingsKey,
      settingsValue: settingsValue ?? this.settingsValue,
    );
  }

  factory SettingModel.fromMap(Map<String, dynamic> map) {
    return SettingModel(
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