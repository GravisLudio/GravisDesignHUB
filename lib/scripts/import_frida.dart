import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bead.dart';
import '../models/bead_color.dart';
import '../models/bead_pattern.dart';
import '../models/pattern_step.dart';
import '../services/storage_service.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final rawSteps = [
    {"pattern": "1D 10P", "note": "Fila 1"},
    {"pattern": "1N 1P 1N 1P", "note": "Fila 2"},
    {"pattern": "1N 4P", "note": "Fila 3"},
    {"pattern": "5P", "note": "Fila 4"},
    {"pattern": "2N 2P 1N", "note": "Fila 5"},
    {"pattern": "1P 3N 1P", "note": "Fila 6"},
    {"pattern": "1N 1P 2N 1P", "note": "Fila 7"},
    {"pattern": "1N 3P 1N", "note": "Fila 8"},
    {"pattern": "1V 1N 2P 1N", "note": "Fila 9"},
    {"pattern": "1M 3N 1A", "note": "Fila 10"},
    {"pattern": "2A 2N 1M", "note": "Fila 11"},
    {"pattern": "1D 3N 1D", "note": "Fila 12"},
    {"pattern": "2A 1O 1R 1M", "note": "Fila 13"},
    {"pattern": "1M 2R 1O 1A", "note": "Fila 14"}
  ];

  List<Bead> parseBeads(String text) {
    if (text.isEmpty) return [];
    List<Bead> beads = [];
    final parts = text.split(' ');
    for (var part in parts) {
      if (part.trim().isEmpty) continue;
      final match = RegExp(r'^(\d+)([A-Z]+)$').firstMatch(part.trim());
      if (match != null) {
        int count = int.parse(match.group(1)!);
        String code = match.group(2)!;
        BeadColor? color = BeadColor.fromCode(code);
        if (color == null) {
          color = BeadColor.blanco; // Default fallback
        }
        for (int i = 0; i < count; i++) {
          if (color == BeadColor.vacio) {
            beads.add(Bead.empty());
          } else {
            beads.add(Bead.colored(color));
          }
        }
      }
    }
    return beads;
  }

  List<PatternStep> parsedSteps = [];

  for (var step in rawSteps) {
    String text = step['pattern']!;
    List<Bead> beads = parseBeads(text);
    if (beads.isNotEmpty) {
      parsedSteps.add(PatternStep(
        instruction: text,
        note: step['note'],
        beads: beads,
      ));
    }
  }

  final pattern = BeadPattern(
    id: 'frida_kahlo_1',
    name: 'Frida Kahlo',
    steps: parsedSteps,
    createdAt: DateTime.now(),
    columns: 2,
    price: 1000.0,
  );

  // Delete older duplicates
  final snapshot = await FirebaseFirestore.instance.collection('patterns').get();
  for (var doc in snapshot.docs) {
    if (doc.id.startsWith('frida_') || doc.data()['name'] == 'Frida Kahlo') {
      await doc.reference.delete();
    }
  }

  await StorageService().savePattern(pattern);

  print("=======================================");
  print("✅ PATRON FRIDA IMPORTADO CON EXITO");
  print("=======================================");
}
