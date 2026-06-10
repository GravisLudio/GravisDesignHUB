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
    {"pattern": "2R 2B 3P 2B 2R 1N", "note": "2 rojas, 2 blan, 3 beiz, 2 blan, 2 roj, 1 neg. Me devuelvo 3ra."},
    {"pattern": "1R 4N 1R", "note": "1 roja, 3 neg, 1 roja (Asumimos 4 negras para completar 6)"},
    {"pattern": "6N", "note": "6 negras"},
    {"pattern": "2N 3P 1N", "note": "2 negr, 3 beiz, 1 neg"},
    {"pattern": "1N 4P 1N", "note": "1 neg, 4 beiz, 1 neg"},
    {"pattern": "1N 2P 1N 2P", "note": "1 neg, 2 beiz, 1 neg, 2 beiz"},
    {"pattern": "2P 2N 2P", "note": "2 beiz, 2 negra, 2 beiz"},
    {"pattern": "1N 1P 1N 1P 1N 1P", "note": "Neg, beiz, Neg, beiz, Neg, beiz"},
    {"pattern": "6P", "note": "6 beiz"},
    {"pattern": "1N 2P 1K 2P", "note": "1 negru 2 beiz, 1 rosada, 2 beiz"},
    {"pattern": "1N 4P 1N", "note": "1 neg, 4 beiz, 1 neg"},
    {"pattern": "2N 3P 1N", "note": "2 negru, 3 beiz, 1 neg"},
    {"pattern": "1N 1P 2N 1P 1N", "note": "1 neg, beiz, 2 neg, beiz, neg"},
    {"pattern": "2N 3P 1N", "note": "2 neg, 3 beiz y 1 neg"},
    {"pattern": "1N 4P 1N", "note": "1 neg, 4 beiz, 1 neg"},
    {"pattern": "2N 3P 1N", "note": "2 ney, 3 beiz, 1 ney"},
    {"pattern": "2N 2P 2N", "note": "2 ney, 2 beiz, 2 ney"},
    {"pattern": "6N", "note": "6 ney"},
    {"pattern": "6N", "note": "6 ney"}
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
    id: 'mafalda_1',
    name: 'Mafalda',
    steps: parsedSteps,
    createdAt: DateTime.now(),
    columns: 2,
    price: 1500.0,
  );

  // Delete older duplicates
  final snapshot = await FirebaseFirestore.instance.collection('patterns').get();
  for (var doc in snapshot.docs) {
    if (doc.id.startsWith('mafalda_') || doc.data()['name'] == 'Mafalda') {
      await doc.reference.delete();
    }
  }

  await StorageService().savePattern(pattern);

  print("=======================================");
  print("✅ PATRON MAFALDA IMPORTADO CON EXITO");
  print("=======================================");
}
