import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoService {
  Db? _db;

  Future<void> connect() async {
    // Memastikan file .env sudah dimuat (opsional jika sudah dimuat di main)
    final uri = dotenv.env['MONGODB_URI'];
    
    if (uri == null || uri.isEmpty) {
      throw Exception("MONGODB_URI tidak ditemukan di file .env atau kosong");
    }

    try {
      _db = await Db.create(uri);
      await _db!.open();
    } catch (e) {
      throw Exception("Gagal membuka koneksi ke MongoDB: $e");
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
    }
  }

  Db get db {
    if (_db == null) {
      throw Exception("Database belum diinisialisasi. Panggil connect() terlebih dahulu.");
    }
    return _db!;
  }
}