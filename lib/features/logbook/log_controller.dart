import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';

class LogController {
  // Data asli yang tersimpan di memori
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  // Data yang ditampilkan di UI (untuk fitur Search)
  final ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier([]);
  
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
  void addLog(String title, String desc, String cat) {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final newLog = LogModel(
      title: title,
      description: desc,
      timestamp: formattedDate, 
      category: cat,
    );
    logsNotifier.value = [...logsNotifier.value, newLog];
    _syncAndSave();
  }

  // --- 3. Update ---
  void updateLog(int index, String title, String desc, cat) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    currentLogs[index] = LogModel(
      title: title,
      description: desc,
      timestamp: formattedDate,
      category: cat,
    );
    logsNotifier.value = currentLogs;
    _syncAndSave();
  }

  // --- 4. Delete ---
  void removeLog(int index) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    // Kita hapus berdasarkan data yang ada di filteredLogs agar tidak salah index saat searching
    final itemToRemove = filteredLogs.value[index];
    currentLogs.removeWhere((item) => item.timestamp == itemToRemove.timestamp);
    
    logsNotifier.value = currentLogs;
    _syncAndSave();
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
        final loadedData = decoded.map((item) => LogModel.fromMap(item)).toList();
        
        logsNotifier.value = loadedData;
        filteredLogs.value = loadedData; // Tampilkan semua saat pertama load
      } catch (e) {
        debugPrint("Error decoding: $e");
      }
    }
  }
}