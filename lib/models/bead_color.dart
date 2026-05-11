import 'package:flutter/material.dart';

class BeadColor {
  final String code;
  final String name;
  final Color color;

  const BeadColor(this.code, this.name, this.color);

  // Preset colors
  static const dorado = BeadColor('D', 'Dorado', Color(0xFFC8A951));
  static const negro = BeadColor('N', 'Negro', Color(0xFF212121));
  static const piel = BeadColor('P', 'Piel', Color(0xFFF5C6A0));
  static const verde = BeadColor('V', 'Verde', Color(0xFF2E7D32));
  static const cafe = BeadColor('C', 'Café', Color(0xFF5D4037));
  static const rojo = BeadColor('R', 'Rojo', Color(0xFFC62828));
  static const amarillo = BeadColor('A', 'Amarillo', Color(0xFFFDD835));
  static const naranja = BeadColor('O', 'Naranja', Color(0xFFEF6C00));
  static const morado = BeadColor('M', 'Morado', Color(0xFFCE93D8));
  static const blanco = BeadColor('B', 'Blanco', Color(0xFFF5F5F5));
  static const rosado = BeadColor('K', 'Rosado', Color(0xFFF48FB1));
  static const azul = BeadColor('Z', 'Azul', Color(0xFF1565C0));

  static List<BeadColor> get values => [
    dorado, negro, piel, verde, cafe, rojo, amarillo, naranja, morado, blanco, rosado, azul
  ];

  static BeadColor? fromCode(String code) {
    try {
      return values.firstWhere(
        (e) => e.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'color': color.value,
  };

  factory BeadColor.fromJson(Map<String, dynamic> json) {
    return BeadColor(
      json['code'] ?? '',
      json['name'] ?? '',
      Color(json['color'] ?? 0xFF000000),
    );
  }
}
