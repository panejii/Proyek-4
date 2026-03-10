import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart'; // <--- Tambahkan ini
// import lainnya...

class LogController {
  // Data asli yang tersimpan di memori
  final ValueNotifier<List<Logbook>> logsNotifier = ValueNotifier<List<Logbook>>([]);  // Data yang ditampilkan di UI (untuk fitur Search)
  final ValueNotifier<List<Logbook>> filteredLogs = ValueNotifier([]);
  
  static const String _storageKey = 'saved_logs_data';

  LogController() {
    loadFromDisk();
  }

  // --- 1. Logika Pencarian (Real-time Filtering) ---
  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = logsNotifier.value;
    } else {
      filteredLogs.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  // --- 2. Create ---
  Future<void> addLog(String title, String desc, String cat) async {
    try {
      // 1. Siapkan data
      final newLogData = Logbook(
        title: title,
        description: desc,
        date: DateTime.now(),
        category: cat,
      );

      // 2. Simpan ke MongoDB & Ambil ID-nya
      final ObjectId? newId = await MongoService().insertLog(newLogData.toMap());

      if (newId != null) {
        // 3. Buat objek lengkap dengan ID
        final logWithId = Logbook(
          id: newId,
          title: title,
          description: desc,
          date: newLogData.date,
          category: cat,
        );

        // 4. UPDATE STATE (PENTING: Gunakan List baru)
        // Kita update logsNotifier dulu
        final updatedList = [logWithId, ...logsNotifier.value];
        logsNotifier.value = updatedList;

        // 5. PAKSA UI REFRESH
        // Isi filteredLogs dengan list yang sama agar ValueListenableBuilder terpicu
        filteredLogs.value = List.from(updatedList);
        
        print("UI harusnya refresh sekarang. Total data: ${filteredLogs.value.length}");
      }
    } catch (e) {
      print("Error addLog: $e");
    }
  }

  // --- 3. Update ---
  void updateLog(int index, String title, String desc, String cat) {
    final currentLogs = List<Logbook>.from(logsNotifier.value);

    currentLogs[index] = Logbook(
      title: title,
      description: desc,
      date: DateTime.now(),
      category: cat,
    );
    logsNotifier.value = currentLogs;
    _syncAndSave();
  }

  // --- 4. Delete ---
  Future<void> removeLog(Logbook logToDelete) async { // Ubah parameter dari int ke Logbook
    try {
      // 1. Hapus dari MongoDB menggunakan ID
      if (logToDelete.id != null) {
        await MongoService().deleteLog(logToDelete.id!);
      }

      // 2. Update logsNotifier (Data Master)
      // Kita buat list baru dan saring semua KECUALI yang ID-nya sama dengan yang dihapus
      final updatedMainList = logsNotifier.value
          .where((element) => element.id != logToDelete.id)
          .toList();
      
      logsNotifier.value = updatedMainList;

      // 3. Update filteredLogs (Data Tampilan)
      // Pastikan filteredLogs juga mendapatkan list yang sama agar UI sinkron
      filteredLogs.value = List.from(updatedMainList);

      print("Berhasil menghapus: ${logToDelete.title}");
    } catch (e) {
      print("Gagal menghapus: $e");
    }
  }

  // --- 5. Persistence Logic ---
  
  // Sinkronisasi antara list asli dan list filter, lalu simpan ke disk
  void _syncAndSave() {
    filteredLogs.value = logsNotifier.value;
    saveToDisk();
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      logsNotifier.value.map((log) => log.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_storageKey);

    if (rawJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson);
        final loadedData = decoded.map((item) => Logbook.fromMap(item)).toList();
        
        logsNotifier.value = loadedData;
        filteredLogs.value = loadedData; // Tampilkan semua saat pertama load
      } catch (e) {
        debugPrint("Error decoding: $e");
      }
    }
  }

  Future<void> loadFromMongo() async {
    final logs = await MongoService().getLogs();

    logsNotifier.value = logs;
    filteredLogs.value = logs;
  }
}