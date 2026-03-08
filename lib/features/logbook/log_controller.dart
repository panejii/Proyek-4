import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/services/mongo_service.dart';

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

    final newLog = Logbook(
      title: title,
      description: desc,
      date: DateTime.now(),
      category: cat,
    );

    // kirim ke MongoDB
    await MongoService().insertLog(newLog.toMap());

    // update UI
    logsNotifier.value = [...logsNotifier.value, newLog];
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
  Future<void> removeLog(int index) async {
    final itemToRemove = filteredLogs.value[index];

    if (itemToRemove.id != null) {
      await MongoService().deleteLog(itemToRemove.id!);
    }

    final currentLogs = List<Logbook>.from(logsNotifier.value);
    currentLogs.removeWhere((log) => log.id == itemToRemove.id);

    logsNotifier.value = currentLogs;
    filteredLogs.value = currentLogs;
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