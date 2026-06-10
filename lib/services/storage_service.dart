import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bead_pattern.dart';
import '../models/work_record.dart';
import '../models/payment_record.dart';

class StorageService {
  static const String _legacyKey = 'saved_patterns';
  static const String _patternsFolder = 'patterns';
  static const String _migrationFlagKey = 'patterns_migrated_to_files_v1';

  // Local fallback filenames
  static const String _worksFilename = 'work_records.json';
  static const String _paymentsFilename = 'payments.json';

  bool _migrationChecked = false;

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  // ---------- Patterns API ----------

  Future<void> savePattern(BeadPattern pattern) async {
    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance
          .collection('patterns')
          .doc(pattern.id)
          .set(pattern.toJson(), SetOptions(merge: true));
      return;
    }

    // Local fallback
    await _ensureMigrated();
    if (kIsWeb) {
      await _saveToPrefs(pattern);
      return;
    }
    final dir = await _patternsDir();
    final file = File('${dir.path}${Platform.pathSeparator}${pattern.id}.json');
    await file.writeAsString(jsonEncode(pattern.toJson()), flush: true);
  }

  Future<List<BeadPattern>> getPatterns() async {
    if (isFirebaseAvailable) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('patterns').get();
        final patterns = snapshot.docs.map((doc) => BeadPattern.fromJson(doc.data())).toList();
        patterns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return patterns;
      } catch (e) {
        // Fallback to cache if internet fails during first load
        final snapshot = await FirebaseFirestore.instance
            .collection('patterns')
            .get(const GetOptions(source: Source.cache));
        final patterns = snapshot.docs.map((doc) => BeadPattern.fromJson(doc.data())).toList();
        patterns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return patterns;
      }
    }

    // Local fallback
    await _ensureMigrated();
    if (kIsWeb) return _loadFromPrefs();

    final dir = await _patternsDir();
    if (!await dir.exists()) return const [];

    final List<BeadPattern> patterns = [];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.json')) continue;
      try {
        final raw = await entity.readAsString();
        patterns.add(BeadPattern.fromJson(jsonDecode(raw)));
      } catch (e) {
        // ignore: avoid_print
        print('Skipping corrupt pattern file ${entity.path}: $e');
      }
    }
    patterns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return patterns;
  }

  Future<void> deletePattern(String id) async {
    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance.collection('patterns').doc(id).delete();
      return;
    }

    // Local fallback
    await _ensureMigrated();
    if (kIsWeb) {
      await _deleteFromPrefs(id);
      return;
    }
    final dir = await _patternsDir();
    final file = File('${dir.path}${Platform.pathSeparator}$id.json');
    if (await file.exists()) await file.delete();
  }

  // ---------- Work Records API ----------

  Future<void> saveWorkRecord(WorkRecord record) async {
    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance
          .collection('work_records')
          .doc(record.id)
          .set(record.toJson(), SetOptions(merge: true));
      return;
    }

    // Local fallback
    final records = await getWorkRecords();
    final idx = records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.add(record);
    }
    await _saveLocalWorks(records);
  }

  Future<List<WorkRecord>> getWorkRecords() async {
    if (isFirebaseAvailable) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('work_records').get();
        final records = snapshot.docs.map((doc) => WorkRecord.fromJson(doc.data())).toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      } catch (e) {
        final snapshot = await FirebaseFirestore.instance
            .collection('work_records')
            .get(const GetOptions(source: Source.cache));
        final records = snapshot.docs.map((doc) => WorkRecord.fromJson(doc.data())).toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      }
    }

    // Local fallback
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_work_records') ?? '[]';
      final List dec = jsonDecode(raw);
      final list = dec.map((e) => WorkRecord.fromJson(e)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final file = await _getWorksFile();
    if (!await file.exists()) return const [];
    try {
      final raw = await file.readAsString();
      final List dec = jsonDecode(raw);
      final list = dec.map((e) => WorkRecord.fromJson(e)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> deleteWorkRecord(String id) async {
    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance.collection('work_records').doc(id).delete();
      return;
    }

    // Local fallback
    final records = await getWorkRecords();
    records.removeWhere((r) => r.id == id);
    await _saveLocalWorks(records);
  }

  // ---------- Payments API ----------

  Future<void> savePayment(PaymentRecord record) async {
    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(record.id)
          .set(record.toJson(), SetOptions(merge: true));
      return;
    }

    // Local fallback
    final payments = await getPayments();
    final idx = payments.indexWhere((p) => p.id == record.id);
    if (idx >= 0) {
      payments[idx] = record;
    } else {
      payments.add(record);
    }
    await _saveLocalPayments(payments);
  }

  Future<List<PaymentRecord>> getPayments() async {
    if (isFirebaseAvailable) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('payments').get();
        final payments = snapshot.docs.map((doc) => PaymentRecord.fromJson(doc.data())).toList();
        payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return payments;
      } catch (e) {
        final snapshot = await FirebaseFirestore.instance
            .collection('payments')
            .get(const GetOptions(source: Source.cache));
        final payments = snapshot.docs.map((doc) => PaymentRecord.fromJson(doc.data())).toList();
        payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return payments;
      }
    }

    // Local fallback
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_payments') ?? '[]';
      final List dec = jsonDecode(raw);
      final list = dec.map((e) => PaymentRecord.fromJson(e)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final file = await _getPaymentsFile();
    if (!await file.exists()) return const [];
    try {
      final raw = await file.readAsString();
      final List dec = jsonDecode(raw);
      final list = dec.map((e) => PaymentRecord.fromJson(e)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> deletePayment(String id) async {
    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance.collection('payments').doc(id).delete();
      return;
    }

    // Local fallback
    final payments = await getPayments();
    payments.removeWhere((p) => p.id == id);
    await _saveLocalPayments(payments);
  }

  // ---------- Internals & Local File Helpers ----------

  Future<File> _getWorksFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}${Platform.pathSeparator}$_worksFilename');
  }

  Future<File> _getPaymentsFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}${Platform.pathSeparator}$_paymentsFilename');
  }

  Future<void> _saveLocalWorks(List<WorkRecord> records) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_work_records', jsonEncode(records.map((r) => r.toJson()).toList()));
      return;
    }
    final file = await _getWorksFile();
    await file.writeAsString(jsonEncode(records.map((r) => r.toJson()).toList()), flush: true);
  }

  Future<void> _saveLocalPayments(List<PaymentRecord> payments) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_payments', jsonEncode(payments.map((p) => p.toJson()).toList()));
      return;
    }
    final file = await _getPaymentsFile();
    await file.writeAsString(jsonEncode(payments.map((p) => p.toJson()).toList()), flush: true);
  }

  Future<Directory> _patternsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_patternsFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _ensureMigrated() async {
    if (_migrationChecked || kIsWeb) {
      _migrationChecked = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationFlagKey) == true) {
      _migrationChecked = true;
      return;
    }
    final legacy = prefs.getStringList(_legacyKey) ?? const [];
    if (legacy.isNotEmpty) {
      final dir = await _patternsDir();
      for (final raw in legacy) {
        try {
          final pattern = BeadPattern.fromJson(jsonDecode(raw));
          final file = File('${dir.path}${Platform.pathSeparator}${pattern.id}.json');
          if (!await file.exists()) {
            await file.writeAsString(raw, flush: true);
          }
        } catch (_) {}
      }
    }
    await prefs.setBool(_migrationFlagKey, true);
    _migrationChecked = true;
  }

  // ---------- Web fallback (SharedPreferences) ----------

  Future<void> _saveToPrefs(BeadPattern pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_legacyKey) ?? const <String>[];
    final patterns = existing.map((s) => BeadPattern.fromJson(jsonDecode(s))).toList();
    final idx = patterns.indexWhere((p) => p.id == pattern.id);
    if (idx >= 0) {
      patterns[idx] = pattern;
    } else {
      patterns.add(pattern);
    }
    await prefs.setStringList(_legacyKey, patterns.map((p) => jsonEncode(p.toJson())).toList());
  }

  Future<List<BeadPattern>> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_legacyKey) ?? const <String>[];
    final patterns = existing.map((s) => BeadPattern.fromJson(jsonDecode(s))).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return patterns;
  }

  Future<void> _deleteFromPrefs(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_legacyKey) ?? const <String>[];
    final patterns = existing.map((s) => BeadPattern.fromJson(jsonDecode(s))).where((p) => p.id != id).toList();
    await prefs.setStringList(_legacyKey, patterns.map((p) => jsonEncode(p.toJson())).toList());
  }
}
