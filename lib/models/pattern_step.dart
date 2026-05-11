import 'bead.dart';

class PatternStep {
  final String instruction;
  final String? note;
  final List<Bead> beads;

  PatternStep({
    required this.instruction,
    this.note,
    required this.beads,
  });

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'note': note,
    'beads': beads.map((b) => b.toJson()).toList(),
  };

  factory PatternStep.fromJson(Map<String, dynamic> json) {
    return PatternStep(
      instruction: json['instruction'] ?? '',
      note: json['note'],
      beads: (json['beads'] as List?)?.map((b) => Bead.fromJson(b)).toList() ?? [],
    );
  }
}
