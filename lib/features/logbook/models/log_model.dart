import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

@HiveType(typeId: 0)
class Logbook {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String date;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String authorId;

  @HiveField(6)
  final String teamId;

  @HiveField(7)
  final bool isSynced; // true = sudah tersimpan di Atlas, false = pending

  Logbook({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    required this.authorId,
    required this.teamId,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': ObjectId.fromHexString(id!),
      'title': title,
      'description': description,
      'date': date,
      'category': category,
      'authorId': authorId,
      'teamId': teamId,
    };
  }

  factory Logbook.fromMap(Map<String, dynamic> map) {
    return Logbook(
      id: map['_id'] is ObjectId ? (map['_id'] as ObjectId).toHexString() : map['_id']?.toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date']?.toString() ?? DateTime.now().toIso8601String(),
      category: map['category'] ?? 'Pribadi',
      authorId: map['authorId'] ?? 'unknown_user',
      teamId: map['teamId'] ?? 'no_team',
      isSynced: true, // Data dari Cloud = sudah synced
    );
  }
}