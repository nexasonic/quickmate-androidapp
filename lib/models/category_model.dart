import '../core/api_config.dart';

class CategoryModel {
  final int id;
  final String name;
  final String? type;
  final String? imageUrl;

  CategoryModel({
    required this.id,
    required this.name,
    this.type,
    this.imageUrl,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawImg = json['image_url']?.toString();

    return CategoryModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      type: json['type']?.toString(),
      imageUrl: rawImg != null ? ApiConfig.fixImageUrl(rawImg) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'image_url': imageUrl,
    };
  }
}
