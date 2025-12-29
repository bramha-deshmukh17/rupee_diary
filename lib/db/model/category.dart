import 'package:flutter/widgets.dart';

class CategoryModel {
  final int id;
  final String name;
  final IconData icon;

  CategoryModel({required this.id, required this.name, required this.icon});

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
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
