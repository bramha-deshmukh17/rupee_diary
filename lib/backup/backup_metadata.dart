class BackupMetadata {
  final String appName;
  final int backupVersion;
  final int dbVersion;
  final String createdAt;

  BackupMetadata({
    required this.appName,
    required this.backupVersion,
    required this.dbVersion,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'appName': appName,
    'backupVersion': backupVersion,
    'dbVersion': dbVersion,
    'createdAt': createdAt,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      appName: json['appName'],
      backupVersion: json['backupVersion'],
      dbVersion: json['dbVersion'],
      createdAt: json['createdAt'],
    );
  }
}
