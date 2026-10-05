import 'package:path/path.dart' as p;

class Profile {
  Profile({
    required this.id,
    required this.name,
    this.imagePath,
  });

  /// The device owner. Always exists and keeps the data created before
  /// profiles were introduced.
  static const String ownerId = 'me';

  final String id;
  final String name;
  final String? imagePath;

  bool get isOwner => id == ownerId;

  Profile copyWith({
    String? name,
    String? imagePath,
    bool clearImage = false,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      imagePath: clearImage ? null : imagePath ?? this.imagePath,
    );
  }

  // Only the image file name is stored: the app documents path changes
  // between app updates on iOS.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': imagePath == null ? null : p.basename(imagePath!),
    };
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    required String imagesDirectory,
  }) {
    final image = json['image'] as String?;

    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: image == null ? null : p.join(imagesDirectory, image),
    );
  }
}
