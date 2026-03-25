import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:logbook_app_020/helpers/log_helper.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class LogController {
  final ValueNotifier<List<Logbook>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Logbook>> filteredLogs = ValueNotifier([]);

  // Hive box sebagai penyimpanan lokal utama
  final Box<Logbook> _myBox = Hive.box<Logbook>('offline_logs');

  // --- 1. Logika Pencarian Real-time ---
  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = logsNotifier.value;
    } else {
      filteredLogs.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  // --- 2. LOAD (Offline-First Strategy) ---
  Future<void> loadLogs(String teamId) async {
    // Langkah 1: Tampilkan data Hive dulu (instan, tanpa internet)
    final localData = _myBox.values.toList();
    logsNotifier.value = localData;
    filteredLogs.value = localData;

    // Langkah 2: Sync dari Cloud di background
    try {
      final cloudData = await MongoService().getLogs(teamId);

      // Update Hive dengan data terbaru dari Cloud
      await _myBox.clear();
      await _myBox.addAll(cloudData);

      logsNotifier.value = cloudData;
      filteredLogs.value = cloudData;

      await LogHelper.writeLog("SYNC: Data berhasil diperbarui dari Atlas", level: 2);
    } catch (e) {
      await LogHelper.writeLog("OFFLINE: Menggunakan data cache lokal", level: 2);
    }
  }

  // --- 3. CREATE (Instant Local + Background Cloud) ---
  Future<void> addLog(
    String title,
    String desc,
    String category,
    String authorId,
    String teamId,
  ) async {
    final newLog = Logbook(
      id: ObjectId().oid,
      title: title,
      description: desc,
      date: DateTime.now().toIso8601String(),
      category: category,
      authorId: authorId,
      teamId: teamId,
    );

    // Simpan ke Hive dulu (instan)
    await _myBox.add(newLog);
    logsNotifier.value = [newLog, ...logsNotifier.value];
    filteredLogs.value = logsNotifier.value;

    // Kirim ke MongoDB di background
    try {
      await MongoService().insertLog(newLog.toMap());
      await LogHelper.writeLog("SUCCESS: Data tersinkron ke Cloud", source: "log_controller.dart");
    } catch (e) {
      await LogHelper.writeLog("WARNING: Data tersimpan lokal, akan sinkron saat online", level: 1);
    }
  }

  // --- 4. UPDATE ---
  Future<void> updateLog(int index, String title, String desc, String category) async {
    final oldLog = logsNotifier.value[index];
    final updatedLog = Logbook(
      id: oldLog.id,
      title: title,
      description: desc,
      date: DateTime.now().toIso8601String(),
      category: category,
      authorId: oldLog.authorId,
      teamId: oldLog.teamId,
    );

    // Update di Hive
    final hiveKey = _myBox.keys.elementAt(index);
    await _myBox.put(hiveKey, updatedLog);

    final updatedList = List<Logbook>.from(logsNotifier.value);
    updatedList[index] = updatedLog;
    logsNotifier.value = updatedList;
    filteredLogs.value = updatedList;

    // Sync ke Cloud
    try {
      await MongoService().updateLog(updatedLog);
    } catch (e) {
      await LogHelper.writeLog("WARNING: Update gagal ke Cloud - $e", level: 1);
    }
  }

  // --- 5. DELETE ---
  Future<void> removeLog(Logbook logToDelete) async {
    try {
      // Hapus dari Hive
      final keyToDelete = _myBox.keys.firstWhere(
        (k) => (_myBox.get(k) as Logbook?)?.id == logToDelete.id,
        orElse: () => null,
      );
      if (keyToDelete != null) await _myBox.delete(keyToDelete);

      // Update notifier
      final updatedList = logsNotifier.value
          .where((e) => e.id != logToDelete.id)
          .toList();
      logsNotifier.value = updatedList;
      filteredLogs.value = updatedList;

      // Hapus dari Cloud
      if (logToDelete.id != null) {
        await MongoService().deleteLog(ObjectId.fromHexString(logToDelete.id!));
      }
    } catch (e) {
      await LogHelper.writeLog("ERROR: Delete gagal - $e", level: 1);
    }
  }
}