import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bead_pattern.dart';

class StorageService {
  static const String _key = 'saved_patterns';

  Future<void> savePattern(BeadPattern pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList(_key) ?? [];
    
    final List<BeadPattern> patterns = existing
        .map((s) => BeadPattern.fromJson(jsonDecode(s)))
        .toList();

    final index = patterns.indexWhere((p) => p.id == pattern.id);
    if (index != -1) {
      patterns[index] = pattern;
    } else {
      patterns.add(pattern);
    }

    final List<String> toSave = patterns
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    
    await prefs.setStringList(_key, toSave);
  }

  Future<List<BeadPattern>> getPatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList(_key) ?? [];
    return existing
        .map((s) => BeadPattern.fromJson(jsonDecode(s)))
        .toList();
  }

  Future<void> deletePattern(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList(_key) ?? [];
    final List<BeadPattern> patterns = existing
        .map((s) => BeadPattern.fromJson(jsonDecode(s)))
        .toList();
    
    patterns.removeWhere((p) => p.id == id);
    
    final List<String> toSave = patterns
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    
    await prefs.setStringList(_key, toSave);
  }
}
