// test/module3_logbook_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';

// ============================================================
// CATATAN:
// Test ini menguji pure logic dari class Logbook (Data Model)
// dan perilaku ValueNotifier secara in-memory tanpa Hive/Mongo.
// File yang dibutuhkan:
//   - lib/features/logbook/models/log_model.dart
// ============================================================

void main() {
  group('Module 3 - Logbook Model & List Logic', () {

    // Helper: buat Logbook dummy untuk keperluan test
    Logbook makeLog({
      String title = 'Test Judul',
      String description = 'Test Deskripsi',
      String category = 'Pribadi',
      String authorId = 'admin',
      String teamId = 'team01',
      bool isSynced = false,
    }) {
      return Logbook(
        id: 'id_test_001',
        title: title,
        description: description,
        date: '2026-04-01T10:00:00.000',
        category: category,
        authorId: authorId,
        teamId: teamId,
        isSynced: isSynced,
      );
    }

    // ----------------------------------------------------------
    // 1. DATA MODEL - Konstruksi & Properti
    // ----------------------------------------------------------

    //1
    test('Logbook object should store title correctly', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final log = makeLog(title: 'Catatan Coding');

      // (2) exercise (act, operate)
      actual = log.title;
      expected = 'Catatan Coding';

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    //2
    test('Logbook isSynced should default to false', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final log = makeLog(); // isSynced tidak diisi = default false

      // (2) exercise (act, operate)
      actual = log.isSynced;
      expected = false;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    //3
    test('Logbook isSynced should be true when set explicitly', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final log = makeLog(isSynced: true);

      // (2) exercise (act, operate)
      actual = log.isSynced;
      expected = true;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // ----------------------------------------------------------
    // 2. SERIALIZATION - toMap & fromMap
    // ----------------------------------------------------------

    //4
    test('toMap should contain correct title key-value', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final log = makeLog(title: 'Judul Simpan');

      // (2) exercise (act, operate)
      final map = log.toMap();
      actual = map['title'];
      expected = 'Judul Simpan';

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    //5
    test('toMap should contain category and description keys', () {
      // (1) setup (arrange, build)
      final log = makeLog(description: 'Isi catatan', category: 'Pekerjaan');

      // (2) exercise (act, operate)
      final map = log.toMap();
      var actual1 = map['description'];
      var expected1 = 'Isi catatan';
      var actual2 = map['category'];
      var expected2 = 'Pekerjaan';

      // (3) verify (assert, check)
      expect(actual1, expected1, reason: 'Expected $expected1 but got $actual1');
      expect(actual2, expected2, reason: 'Expected $expected2 but got $actual2');
    });

    //6
    test('fromMap should build Logbook with correct title and description', () {
      var actual1, expected1, actual2, expected2;
      // (1) setup (arrange, build)
      final map = {
        '_id': 'abc123',
        'title': 'Dari Map',
        'description': 'Deskripsi dari map',
        'date': '2026-04-01T10:00:00.000',
        'category': 'Pribadi',
        'authorId': 'admin',
        'teamId': 'team01',
      };

      // (2) exercise (act, operate)
      final log = Logbook.fromMap(map);
      actual1 = log.title;
      expected1 = 'Dari Map';
      actual2 = log.description;
      expected2 = 'Deskripsi dari map';

      // (3) verify (assert, check)
      expect(actual1, expected1, reason: 'Expected $expected1 but got $actual1');
      expect(actual2, expected2, reason: 'Expected $expected2 but got $actual2');
    });

    //7
    test('fromMap should use default values when fields are missing', () {
      var actual1, expected1, actual2, expected2;
      // (1) setup - map tidak lengkap (tanpa category dan authorId)
      final incompleteMap = {
        'title': '',
        'description': '',
        'date': '2026-04-01T10:00:00.000',
      };

      // (2) exercise (act, operate)
      final log = Logbook.fromMap(incompleteMap);
      actual1 = log.category;
      expected1 = 'Pribadi'; // default value dari fromMap
      actual2 = log.authorId;
      expected2 = 'unknown_user'; // default value dari fromMap

      // (3) verify (assert, check)
      expect(actual1, expected1, reason: 'Expected $expected1 but got $actual1');
      expect(actual2, expected2, reason: 'Expected $expected2 but got $actual2');
    });

    // ----------------------------------------------------------
    // 3. LIST LOGIC - Simulasi CRUD in-memory dengan ValueNotifier
    // ----------------------------------------------------------

    //8
    test('adding a log to ValueNotifier list should increase length by 1', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final logsNotifier = ValueNotifier<List<Logbook>>([]);
      final newLog = makeLog(title: 'Log Baru');

      // (2) exercise (act, operate)
      logsNotifier.value = [newLog, ...logsNotifier.value];
      actual = logsNotifier.value.length;
      expected = 1;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');

      logsNotifier.dispose();
    });

    //9
    test('removing a log by id should decrease list length by 1', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final log1 = makeLog(title: 'Log Satu');
      final log2 = Logbook(
        id: 'id_test_002',
        title: 'Log Dua',
        description: 'Deskripsi dua',
        date: '2026-04-01T11:00:00.000',
        category: 'Pekerjaan',
        authorId: 'admin',
        teamId: 'team01',
      );
      final logsNotifier = ValueNotifier<List<Logbook>>([log1, log2]);

      // (2) exercise (act, operate) - hapus log1 berdasarkan id
      logsNotifier.value =
          logsNotifier.value.where((e) => e.id != log1.id).toList();
      actual = logsNotifier.value.length;
      expected = 1;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');

      logsNotifier.dispose();
    });

    //10
    test('searchLog logic should filter logs by title (case-insensitive)', () {
      var actual, expected;
      // (1) setup (arrange, build)
      final logs = [
        makeLog(title: 'Belajar Flutter'),
        Logbook(
          id: 'id_test_003',
          title: 'Tugas Proyek',
          description: 'Deskripsi tugas',
          date: '2026-04-01T12:00:00.000',
          category: 'Pekerjaan',
          authorId: 'admin',
          teamId: 'team01',
        ),
        Logbook(
          id: 'id_test_004',
          title: 'Latihan Flutter',
          description: 'Latihan widget',
          date: '2026-04-01T13:00:00.000',
          category: 'Pribadi',
          authorId: 'admin',
          teamId: 'team01',
        ),
      ];

      // (2) exercise (act, operate) - simulasi logika searchLog dengan query 'flutter'
      final String query = 'flutter';
      final filtered = logs
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
      actual = filtered.length;
      expected = 2; // "Belajar Flutter" dan "Latihan Flutter"

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });
  });
}
