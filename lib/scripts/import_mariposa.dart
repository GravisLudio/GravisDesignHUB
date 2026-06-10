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
    {"beads": ["c1", "c1", "c2", "neg", "neg", "neg", "c1", "c1", "blan"], "note": "Fila inicial. Regresa por la 3ra pepa."},
    {"beads": ["c3", "c2", "c2"], "note": "Fila de 3 cuentas."},
    {"beads": ["c2", "c2", "neg", "c1"]},
    {"beads": ["c1", "c3", "c2", "c2"]},
    {"beads": ["neg", "c2", "neg", "c3"]},
    {"beads": ["neg", "c3", "c2", "neg"]},
    {"beads": ["extra", "extra", "extra", "extra"], "note": "Cuerpo central."},
    {"beads": ["extra", "extra", "extra", "extra"]},
    {"beads": ["extra", "extra", "extra", "extra"]},
    {"beads": ["neg", "c3", "c2", "neg"]},
    {"beads": ["neg", "c2", "neg", "c3"]},
    {"beads": ["c1", "c3", "c2", "c2"]},
    {"beads": ["c2", "c2", "neg", "c1"]},
    {"beads": ["blan", "c3", "c2", "c2"]},
    {"beads": ["c1", "c2", "neg", "c1"]},
    {"beads": ["c1", "neg", "neg", "c1"], "note": "Fin de sección."}
  ];

  BeadColor mapColor(String code) {
    switch (code) {
      case 'c1': return BeadColor.amarillo;
      case 'c2': return BeadColor.naranja;
      case 'c3': return BeadColor.rojoOscuro;
      case 'extra': return BeadColor.dorado;
      case 'neg': return BeadColor.negro;
      case 'blan': return BeadColor.blanco;
      default: return BeadColor.vacio;
    }
  }

  List<PatternStep> parsedSteps = [];

  for (var step in rawSteps) {
    List<String> beadCodes = (step['beads'] as List<String>);
    List<Bead> beads = beadCodes.map((c) => Bead.colored(mapColor(c))).toList();
    
    // Generate instruction string manually
    String instruction = beadCodes.join(', ').replaceAll('c1', '1A').replaceAll('c2', '1O').replaceAll('c3', '1RO').replaceAll('extra', '1D').replaceAll('neg', '1N').replaceAll('blan', '1B');

    parsedSteps.add(PatternStep(
      instruction: instruction,
      note: step['note'] as String?,
      beads: beads,
    ));
  }

  final pattern = BeadPattern(
    id: 'mariposa_monarca_1',
    name: 'Mariposa Monarca',
    steps: parsedSteps,
    createdAt: DateTime.now(),
    columns: 2,
    price: 1000.0,
  );

  // Delete older duplicates
  final snapshot = await FirebaseFirestore.instance.collection('patterns').get();
  for (var doc in snapshot.docs) {
    if (doc.id.startsWith('mariposa_') || doc.data()['name'] == 'Mariposa Monarca') {
      await doc.reference.delete();
    }
  }

  await StorageService().savePattern(pattern);

  print("=======================================");
  print("✅ PATRON MARIPOSA IMPORTADO CON EXITO");
  print("=======================================");
}
