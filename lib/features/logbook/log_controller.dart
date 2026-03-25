import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:logbook_app_020/helpers/log_helper.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class LogController {
  final ValueNotifier<List<Logbook>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Logbook>> filteredLogs = ValueNotifier([]);

  // Status koneksi yang bisa dipantau dari UI
  final ValueNotifier<bool> isOnline = ValueNotifier(false);

  final Box<Logbook> _myBox = Hive.box<Logbook>('offline_logs');

  LogController() {
    _connectivityReady = _initConnectivity();
  }

  // Future ini bisa di-await oleh LogView agar isOnline sudah terisi sebelum loadLogs
  late final Future<void> _connectivityReady;

  // --- Connectivity Setup ---
  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = result != ConnectivityResult.none;

    Connectivity().onConnectivityChanged.listen((result) async {
      final nowOnline = result != ConnectivityResult.none;
      final wasOffline = !isOnline.value;
      isOnline.value = nowOnline;

      if (nowOnline && wasOffline) {
        await LogHelper.writeLog("CONNECTIVITY: Koneksi pulih, sync pending...", level: 2);
        await _syncPendingLogs();
        // Refresh notifier UI setelah sync selesai
        logsNotifier.value = _myBox.values.toList();
        filteredLogs.value = logsNotifier.value;
      }
    });
  }

  Future<void> waitForConnectivity() => _connectivityReady;

  // Sync semua data Hive yang belum tersinkron (isSynced == false)
  Future<void> _syncPendingLogs() async {
    final pendingLogs = _myBox.values.where((l) => !l.isSynced).toList();
    if (pendingLogs.isEmpty) return;

    await LogHelper.writeLog("SYNC: Ditemukan ${pendingLogs.length} log pending", level: 2);

    for (final log in pendingLogs) {
      try {
        await MongoService().insertLog(log.toMap());

        // Tandai sebagai sudah synced di Hive
        final key = _myBox.keys.firstWhere(
          (k) => (_myBox.get(k) as Logbook?)?.id == log.id,
          orElse: () => null,
        );
        if (key != null) {
          final synced = Logbook(
            id: log.id, title: log.title, description: log.description,
            date: log.date, category: log.category,
            authorId: log.authorId, teamId: log.teamId, isSynced: true,
          );
          await _myBox.put(key, synced);
        }

        await LogHelper.writeLog("SYNC: '${log.title}' berhasil diunggah ke Atlas", level: 2);
      } catch (e) {
        await LogHelper.writeLog("SYNC: Gagal upload '${log.title}' - $e", level: 1);
      }
    }

    // Refresh notifier setelah sync
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = logsNotifier.value;
  }

  // --- Pencarian ---
  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = logsNotifier.value;
    } else {
      filteredLogs.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  // --- LOAD (Offline-First) ---
  Future<void> loadLogs(String teamId) async {
    // Tampilkan Hive dulu (instan, selalu)
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = logsNotifier.value;

    if (!isOnline.value) {
      await LogHelper.writeLog("OFFLINE: Menampilkan data cache lokal", level: 2);
      return;
    }

    // Kalau online: upload pending dulu SEBELUM pull dari Cloud
    // supaya data offline tidak hilang tertimpa
    await _syncPendingLogs();

    try {
      final cloudData = await MongoService().getLogs(teamId);
      // Hanya clear setelah pending sudah dikirim ke Atlas
      await _myBox.clear();
      await _myBox.addAll(cloudData);
      logsNotifier.value = cloudData;
      filteredLogs.value = cloudData;
      await LogHelper.writeLog("SYNC: Data berhasil diperbarui dari Atlas", level: 2);
    } catch (e) {
      await LogHelper.writeLog("ERROR: Sync gagal - $e", level: 1);
    }
  }

  // --- CREATE ---
  Future<void> addLog(
    String title, String desc, String category,
    String authorId, String teamId,
  ) async {
    final newLog = Logbook(
      id: ObjectId().oid,
      title: title,
      description: desc,
      date: DateTime.now().toIso8601String(),
      category: category,
      authorId: authorId,
      teamId: teamId,
      isSynced: false, // Belum dikirim ke Atlas
    );

    // Simpan ke Hive dulu (selalu, online maupun offline)
    await _myBox.add(newLog);
    logsNotifier.value = [newLog, ...logsNotifier.value];
    filteredLogs.value = logsNotifier.value;

    if (!isOnline.value) {
      await LogHelper.writeLog("OFFLINE: '${newLog.title}' disimpan lokal, menunggu koneksi", level: 2);
      return;
    }

    // Kalau online, langsung kirim ke Atlas dan update flag isSynced
    try {
      await MongoService().insertLog(newLog.toMap());

      final key = _myBox.keys.lastWhere(
        (k) => (_myBox.get(k) as Logbook?)?.id == newLog.id,
        orElse: () => null,
      );
      if (key != null) {
        await _myBox.put(key, Logbook(
          id: newLog.id, title: newLog.title, description: newLog.description,
          date: newLog.date, category: newLog.category,
          authorId: newLog.authorId, teamId: newLog.teamId, isSynced: true,
        ));
      }

      // Update notifier dengan status synced
      final idx = logsNotifier.value.indexWhere((l) => l.id == newLog.id);
      if (idx != -1) {
        final updated = List<Logbook>.from(logsNotifier.value);
        updated[idx] = Logbook(
          id: newLog.id, title: newLog.title, description: newLog.description,
          date: newLog.date, category: newLog.category,
          authorId: newLog.authorId, teamId: newLog.teamId, isSynced: true,
        );
        logsNotifier.value = updated;
        filteredLogs.value = updated;
      }

      await LogHelper.writeLog("SUCCESS: '${newLog.title}' tersinkron ke Atlas", level: 2);
    } catch (e) {
      await LogHelper.writeLog("WARNING: Simpan lokal, gagal ke Atlas - $e", level: 1);
    }
  }

  // --- UPDATE ---
  Future<void> updateLog(int index, String title, String desc, String category) async {
    final oldLog = logsNotifier.value[index];
    final updatedLog = Logbook(
      id: oldLog.id, title: title, description: desc,
      date: DateTime.now().toIso8601String(), category: category,
      authorId: oldLog.authorId, teamId: oldLog.teamId,
      isSynced: isOnline.value,
    );

    final hiveKey = _myBox.keys.firstWhere(
      (k) => (_myBox.get(k) as Logbook?)?.id == oldLog.id,
      orElse: () => null,
    );
    if (hiveKey != null) await _myBox.put(hiveKey, updatedLog);

    final updatedList = List<Logbook>.from(logsNotifier.value);
    updatedList[index] = updatedLog;
    logsNotifier.value = updatedList;
    filteredLogs.value = updatedList;

    if (isOnline.value) {
      try {
        await MongoService().updateLog(updatedLog);
      } catch (e) {
        await LogHelper.writeLog("WARNING: Update gagal ke Atlas - $e", level: 1);
      }
    }
  }

  // --- DELETE ---
  Future<void> removeLog(Logbook logToDelete) async {
    try {
      final keyToDelete = _myBox.keys.firstWhere(
        (k) => (_myBox.get(k) as Logbook?)?.id == logToDelete.id,
        orElse: () => null,
      );
      if (keyToDelete != null) await _myBox.delete(keyToDelete);

      final updatedList = logsNotifier.value
          .where((e) => e.id != logToDelete.id)
          .toList();
      logsNotifier.value = updatedList;
      filteredLogs.value = updatedList;

      if (isOnline.value && logToDelete.id != null) {
        await MongoService().deleteLog(ObjectId.fromHexString(logToDelete.id!));
      }
    } catch (e) {
      await LogHelper.writeLog("ERROR: Delete gagal - $e", level: 1);
    }
  }

  void dispose() {
    isOnline.dispose();
    logsNotifier.dispose();
    filteredLogs.dispose();
  }
}