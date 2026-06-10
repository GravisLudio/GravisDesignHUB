import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gravdesinghub/firebase_options.dart';
import 'package:gravdesinghub/models/bead_pattern.dart';
import 'package:gravdesinghub/models/pattern_step.dart';
import 'package:gravdesinghub/models/bead.dart';
import 'package:gravdesinghub/models/bead_color.dart';
import 'package:gravdesinghub/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

List<Bead> parseBeads(String pattern) {
  if (pattern.contains('REDUCCION') || pattern.contains('Paso') || pattern.contains('Notaras') || pattern.contains('Los siguientes') || pattern.contains('ahora que') || pattern.contains('Ahora justo') || pattern.contains('Subes por') || pattern.contains('ahora solo') || pattern.contains('PONER UNA V') || pattern.contains('Aqui haremos') || pattern.contains('Prepara')) {
    return [];
  }

  List<Bead> beads = [];
  final parts = pattern.split(' ');
  for (var p in parts) {
    p = p.trim();
    if (p.isEmpty) continue;
    
    // Find the number and the letter
    final match = RegExp(r'(\d+)([A-Z])').firstMatch(p);
    if (match != null) {
      int count = int.parse(match.group(1)!);
      String code = match.group(2)!;
      BeadColor? color;
      switch (code) {
        case 'D': color = BeadColor.dorado; break;
        case 'N': color = BeadColor.negro; break;
        case 'P': color = BeadColor.piel; break;
        case 'V': color = BeadColor.verde; break;
        case 'C': color = BeadColor.cafe; break;
        case 'R': color = BeadColor.rojo; break;
        case 'M': color = BeadColor.amarillo; break; // Mostaza -> Amarillo
        case 'A': color = BeadColor.amarillo; break;
        case 'O': color = BeadColor.naranja; break;
        case 'X': color = BeadColor.vacio; break;
        default: color = BeadColor.blanco;
      }
      for (int i = 0; i < count; i++) {
        beads.add(Bead.colored(color));
      }
    }
  }
  return beads;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final rawSteps = [
    {"pattern": "Prepara tu espacio de trabajo."},
    {"pattern": "1D 2N 10P 1N 1D 4V"},
    {"pattern": "1D 1N 5P 1N"},
    {"pattern": "1D 3P 2C 1P 1N 1V"},
    {"pattern": "1V 1D 1N 3C 1P 1C 1N"},
    {"pattern": "1D 2C 4P 1N 1V"},
    {"pattern": "1V 1D 6P 1N"},
    {"pattern": "1D 3P 2N 1P 1N 1V"},
    {"pattern": "1V 1D 2P 1N 3P 1N"},
    {"pattern": "1D 2N 4P 1N 1V"},
    {"pattern": "1V 1D 4P 1C 2N"},
    {"pattern": "1D 1C 5P 1N 1V"},
    {"pattern": "2D 4P 1C 1P 1N"},
    {"pattern": "1D 1C 1P 1C 3P 1N 1V"},
    {"pattern": "1V 1D 5P 1C 1N"},
    {"pattern": "1D 1N 5P 1N 1V"},
    {"pattern": "1V 1D 2P 2C 1P 1C 1D"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "1X 1N 1M 1P 1M 1P 1M 1N 1V"},
    {"pattern": "1V 1D 1P 1M 2P 1M 1N 1X"},
    {"pattern": "Notaras que quedas justo en una pepa negra, debes subir a la dorada y agregaras una dorada"},
    {"pattern": "Los siguientes pasos son una explicacion grafica de la reduccion tipo 1"},
    {"pattern": "ahora que el hilo sale por la pepa dorada, y tienes una dorada en la aguja, debereas pasar la agua por la negra justo debajo"},
    {"pattern": "Ahora justo detras de la pepa donde quedo el hielo metras la aguja hacia el lado contrario que salio el hilo"},
    {"pattern": "Subes por la dorada siguiendo la direccion del hilo"},
    {"pattern": "ahora solo pon la aguaja en la dorada que pusiste antes."},
    {"pattern": "1X 1D 1N 1M 1P 1M 1P 1D 1V"},
    {"pattern": "1D 1V 2P 2M 2N 1X"},
    {"pattern": "1X 1D 2N 1M 2P 1D 1V"},
    {"pattern": "2V 3P 3N 1X"},
    {"pattern": "1X 1D 2N 3P 1D 1V"},
    {"pattern": "1V 1D 1R 2P 1R 1N 1D 1X"},
    {"pattern": "1X 1V 1N 5R 1D"},
    {"pattern": "1V 1D 5R 1D 1X"},
    {"pattern": "1X 1V 6R 1V"},
    {"pattern": "1V 1D 5R 1D 1X"},
    {"pattern": "1X 1V 2R 1P 3R 1V"},
    {"pattern": "1V 1D 2R 2P 1R 1D 1X"},
    {"pattern": "1X 1V 1R 1C 2P 2R 1V"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "1X 1D 2R 2P 1R 1D 1X"},
    {"pattern": "1X 1V 1R 3P 2R 1X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "2X 1R 2P 1C 1R 1D 1X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "2X 1R 3P 1R 2X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "3X 2P 1C 1R 2X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "3X 3P 3X"}
  ];

  final leftSteps = [
    {"pattern": "1D 1N 4P 1N 1D 1V"},
    {"pattern": "2V 1D 1N 3P 1N 1D"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "1X 2N 2P 1N 1D 1V 1D"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "1X 2V 1D 4N 1X"},
    {"pattern": "Aqui haremos lo explicado en el paso anterior, son los mismos pasos, debes agregar una pepa D"},
    {"pattern": "1X 1D 3N 1D 2V 1X"},
    {"pattern": "PONER UNA V Y PONER EL HILO EN ESA"},
    {"pattern": "1X 1V 1D 1V 1D 2N 1D 1X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "2X 1D 1N 1D 3V 1X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "2X 3V 2D 2X"},
    {"pattern": "REDUCCION (Reducción Tipo 2)"},
    {"pattern": "3X 1D 3V 2X"}
  ];

  List<PatternStep> parsedSteps = [];
  
  for (var step in rawSteps) {
    String text = step['pattern']!;
    List<Bead> beads = parseBeads(text);
    if (beads.isNotEmpty) {
      parsedSteps.add(PatternStep(
        instruction: text,
        note: null,
        beads: beads,
      ));
    }
  }
  
  for (var step in leftSteps) {
    String text = step['pattern']!;
    List<Bead> beads = parseBeads(text);
    if (beads.isNotEmpty) {
      parsedSteps.add(PatternStep(
        instruction: text,
        note: 'LEFT_SIDE',
        beads: beads,
      ));
    }
  }

  final pattern = BeadPattern(
    id: "virgen_maria_fixed",
    name: "Virgen María",
    steps: parsedSteps,
    createdAt: DateTime.now(),
    price: 4000,
  );

  // Delete all existing Virgen patterns to avoid confusion
  final _db = FirebaseFirestore.instance;
  final snapshot = await _db.collection('patterns').where('name', isEqualTo: 'Virgen María').get();
  for (var doc in snapshot.docs) {
    await doc.reference.delete();
  }

  await StorageService().savePattern(pattern);
  print('=======================================');
  print('✅ PATRON IMPORTADO CON EXITO (LIMPIEZA DE DUPLICADOS REALIZADA)');
  print('=======================================');
  exit(0);
}
