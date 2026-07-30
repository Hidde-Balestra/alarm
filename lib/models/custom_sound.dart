/// A user-uploaded alarm/timer sound. [relativePath] is relative to the
/// app's documents directory (per the `alarm` plugin's requirement that
/// custom audio paths survive app updates), e.g. `custom_sounds/<id>.mp3`.
class CustomSound {
  final String id;
  final String name;
  final String relativePath;

  const CustomSound({required this.id, required this.name, required this.relativePath});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relativePath': relativePath,
      };

  factory CustomSound.fromJson(Map<String, dynamic> json) => CustomSound(
        id: json['id'] as String,
        name: json['name'] as String,
        relativePath: json['relativePath'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is CustomSound &&
      other.id == id &&
      other.name == name &&
      other.relativePath == relativePath;

  @override
  int get hashCode => Object.hash(id, name, relativePath);
}
