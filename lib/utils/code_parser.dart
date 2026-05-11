import '../models/bead.dart';
import '../models/bead_color.dart';

class CodeParser {
  static List<Bead> parse(String input) {
    List<Bead> beads = [];
    final parts = input.trim().split(RegExp(r'\s+'));

    for (var part in parts) {
      if (part.isEmpty) continue;

      final match = RegExp(r'(\d+)([a-zA-Z]+)').firstMatch(part);
      if (match != null) {
        int count = int.parse(match.group(1)!);
        String code = match.group(2)!;
        BeadColor? color = BeadColor.fromCode(code);

        if (color != null) {
          for (int i = 0; i < count; i++) {
            beads.add(Bead.colored(color));
          }
        }
      }
    }
    return beads;
  }
}
