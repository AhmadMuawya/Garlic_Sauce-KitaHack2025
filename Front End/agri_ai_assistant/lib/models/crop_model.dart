import 'package:flutter/foundation.dart';

@immutable
class Crop {
  final String id;
  final String name;
  final String imagePath;

  final String description;

  const Crop({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.description,
  });

  // compare Crop objects directly or store them in Sets/Maps.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Crop &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          imagePath == other.imagePath;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ imagePath.hashCode;
}
