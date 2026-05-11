import '../models/bead.dart';
import '../models/bead_color.dart';

class InstructionParser {
  static List<Bead> parse(String instruction) {
    if (instruction.isEmpty) return [];

    final List<Bead> result = [];
    
    // Normalize string: lowercase
    final normalized = instruction.toLowerCase();
    
    // Match patterns like "9 negras", "9n", "10 doradas", "5piel", etc.
    // (\d+)? -> optional number
    // \s* -> optional whitespace
    // ([a-z]+) -> color code or name
    final matches = RegExp(r'(\d+)?\s*([a-zñáéíóú]+)').allMatches(normalized);

    for (final match in matches) {
      final countStr = match.group(1);
      final label = match.group(2);
      
      if (label != null) {
        final count = countStr != null ? int.parse(countStr) : 1;
        final color = _findColor(label);
        
        if (color != null) {
          for (int i = 0; i < count; i++) {
            result.add(Bead.colored(color));
          }
        }
      }
    }

    return result;
  }

  static BeadColor? _findColor(String label) {
    // Try by code first (single letter)
    if (label.length == 1) {
      final byCode = BeadColor.fromCode(label);
      if (byCode != null) return byCode;
    }

    // Try by name (partial match)
    // Remove common plural suffixes 's' or 'es' to match better
    String normalizedLabel = label;
    if (label.endsWith('as') || label.endsWith('os')) {
      normalizedLabel = label.substring(0, label.length - 1);
    } else if (label.endsWith('es') && label.length > 3) {
      normalizedLabel = label.substring(0, label.length - 2);
    }

    for (final color in BeadColor.values) {
      final name = color.name.toLowerCase();
      if (name == normalizedLabel || 
          name.startsWith(normalizedLabel) || 
          normalizedLabel.startsWith(name)) {
        return color;
      }
    }
    
    return null;
  }
}
