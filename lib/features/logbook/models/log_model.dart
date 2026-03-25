import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

@HiveType(typeId: 0)
class Logbook {
  @HiveField(0)
  final String? id; // Kita gunakan String agar kompatibel dengan Hive & UI

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String date; // Konsisten sebagai String

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String authorId;

  @HiveField(6)
  final String teamId;

  Logbook({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    required this.authorId,
    required this.teamId,
  });

  // Memasukkan data ke Map untuk dikirim ke MongoDB
  Map<String, dynamic> toMap() {
    return {
      // Jika id ada, ubah String kembali ke ObjectId untuk MongoDB
      if (id != null) '_id': ObjectId.fromHexString(id!), 
      'title': title,
      'description': description,
      'date': date, 
      'category': category,
      'authorId': authorId,
      'teamId': teamId,
    };
  }

  // Membongkar data dari MongoDB kembali menjadi objek Flutter
  factory Logbook.fromMap(Map<String, dynamic> map) {
    return Logbook(
      // Pastikan _id dari Mongo (ObjectId) diubah ke String agar masuk ke variabel id
      id: map['_id'] is ObjectId ? (map['_id'] as ObjectId).toHexString() : map['_id']?.toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      // Pastikan tetap String
      date: map['date']?.toString() ?? DateTime.now().toIso8601String(),
      category: map['category'] ?? 'Pribadi',
      authorId: map['authorId'] ?? 'unknown_user',
      teamId: map['teamId'] ?? 'no_team',
    );
  }
}