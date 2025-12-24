import 'package:flutter/widgets.dart';

class Category {
  final int id;
  final String name;
  final IconData icon;

  Category({required this.id, required this.name, required this.icon});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      icon: IconData(
        map['icon_code_point'] as int,
        fontFamily: map['icon_font_family'] as String?,
        fontPackage: map['icon_font_package'] as String?,
      ),
    );
  }
}
