import 'package:flutter/material.dart';

class BeadColor {
  final String code;
  final String name;
  final Color color;

  const BeadColor(this.code, this.name, this.color);

  // Preset colors
  static const dorado = BeadColor('D', 'Dorado', Color(0xFFC8A951));
  static const plata = BeadColor('SL', 'Plata', Color(0xFFBDBDBD));
  static const negro = BeadColor('N', 'Negro', Color(0xFF212121));
  static const piel = BeadColor('P', 'Piel', Color(0xFFF5C6A0));
  static const cafe = BeadColor('C', 'Café', Color(0xFF5D4037));
  static const blanco = BeadColor('B', 'Blanco', Color(0xFFF5F5F5));
  static const gris = BeadColor('GR', 'Gris', Color(0xFF9E9E9E));
  
  // Reds / Oranges / Yellows
  static const rojo = BeadColor('R', 'Rojo', Color(0xFFC62828));
  static const rojoOscuro = BeadColor('RO', 'Rojo Oscuro', Color(0xFF8B0000));
  static const naranja = BeadColor('O', 'Naranja', Color(0xFFEF6C00));
  static const amarillo = BeadColor('A', 'Amarillo', Color(0xFFFDD835));
  
  // Greens
  static const verde = BeadColor('V', 'Verde', Color(0xFF2E7D32));
  static const verdeLima = BeadColor('VL', 'Verde Lima', Color(0xFFC0CA33));
  static const verdeEsmeralda = BeadColor('VE', 'Esmeralda', Color(0xFF00C853));
  
  // Blues
  static const azul = BeadColor('Z', 'Azul', Color(0xFF1565C0));
  static const azulClaro = BeadColor('ZC', 'Azul Claro', Color(0xFF64B5F6));
  static const azulMarino = BeadColor('ZM', 'Azul Marino', Color(0xFF1A237E));
  static const turquesa = BeadColor('T', 'Turquesa', Color(0xFF00CED1));
  
  // Purples / Pinks
  static const morado = BeadColor('M', 'Morado', Color(0xFFCE93D8));
  static const violeta = BeadColor('VI', 'Violeta', Color(0xFF9C27B0));
  static const rosado = BeadColor('K', 'Rosado', Color(0xFFF48FB1));
  static const fucsia = BeadColor('F', 'Fucsia', Color(0xFFE91E63));

  static List<BeadColor> get values => [
    dorado, plata, negro, piel, cafe, blanco, gris,
    rojo, rojoOscuro, naranja, amarillo,
    verde, verdeLima, verdeEsmeralda,
    azul, azulClaro, azulMarino, turquesa,
    morado, violeta, rosado, fucsia
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
