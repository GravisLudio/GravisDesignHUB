import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bead_pattern.dart';

/// Persists user patterns to durable storage.
///
/// Storage layout:
///   - Mobile / desktop: each pattern stored as its own JSON file in
///     `<app documents dir>/patterns/<id>.json`. Files survive app close
///     indefinitely; only removed when the user uninstalls the app or
///     manually clears its data.
///   - Web: `SharedPreferences` (localStorage), since `dart:io` File is not
///     available on web.
///
/// On first launch after the file-storage migration, any patterns still in
/// SharedPreferences are copied into per-file storage so existing users do
/// not lose their data.
class StorageService {
  static const String _legacyKey = 'saved_patterns';
  static const String _patternsFolder = 'patterns';
  static const String _migrationFlagKey = 'patterns_migrated_to_files_v1';

  bool _migrationChecked = false;

  // ---------- Public API ----------

  Future<void> savePattern(BeadPattern pattern) async {
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
        // Skip corrupt file — keep loading the rest.
        // ignore: avoid_print
        print('Skipping corrupt pattern file ${entity.path}: $e');
      }
    }
    // Newest first.
    patterns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return patterns;
  }

  Future<void> deletePattern(String id) async {
    await _ensureMigrated();
    if (kIsWeb) {
      await _deleteFromPrefs(id);
      return;
    }
    final dir = await _patternsDir();
    final file = File('${dir.path}${Platform.pathSeparator}$id.json');
    if (await file.exists()) await file.delete();
  }

  /// Returns the absolute path of the patterns folder (mobile/desktop) or
  /// null on web. Useful to show the user where their data lives.
  Future<String?> getPatternsFolderPath() async {
    if (kIsWeb) return null;
    final dir = await _patternsDir();
    return dir.path;
  }

  // ---------- Internals ----------

  Future<Directory> _patternsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${docs.path}${Platform.pathSeparator}$_patternsFolder',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// One-time copy of any legacy SharedPreferences patterns into per-file
  /// storage. Safe to call repeatedly — runs at most once per install
  /// thanks to the `_migrationFlagKey` flag.
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
          final file = File(
            '${dir.path}${Platform.pathSeparator}${pattern.id}.json',
          );
          if (!await file.exists()) {
            await file.writeAsString(raw, flush: true);
          }
        } catch (_) {/* ignore corrupt legacy entries */}
      }
    }
    await prefs.setBool(_migrationFlagKey, true);
    _migrationChecked = true;
  }

  // ---------- Web fallback (SharedPreferences / localStorage) ----------

  Future<void> _saveToPrefs(BeadPattern pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_legacyKey) ?? const <String>[];
    final patterns = existing
        .map((s) => BeadPattern.fromJson(jsonDecode(s)))
        .toList();
    final idx = patterns.indexWhere((p) => p.id == pattern.id);
    if (idx >= 0) {
      patterns[idx] = pattern;
    } else {
      patterns.add(pattern);
    }
    await prefs.setStringList(
      _legacyKey,
      patterns.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<List<BeadPattern>> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_legacyKey) ?? const <String>[];
    final patterns =
        existing.map((s) => BeadPattern.fromJson(jsonDecode(s))).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return patterns;
  }

  Future<void> _deleteFromPrefs(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_legacyKey) ?? const <String>[];
    final patterns = existing
        .map((s) => BeadPattern.fromJson(jsonDecode(s)))
        .where((p) => p.id != id)
        .toList();
    await prefs.setStringList(
      _legacyKey,
      patterns.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
