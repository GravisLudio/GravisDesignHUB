import 'pattern_step.dart';

class BeadPattern {
  final String id;
  final String name;
  final List<PatternStep> steps;
  final DateTime createdAt;
  final int columns;

  BeadPattern({
    required this.id,
    required this.name,
    required this.steps,
    required this.createdAt,
    this.columns = 2,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'steps': steps.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'columns': columns,
  };

  factory BeadPattern.fromJson(Map<String, dynamic> json) {
    return BeadPattern(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      steps: (json['steps'] as List?)?.map((s) => PatternStep.fromJson(s)).toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      columns: json['columns'] ?? 2,
    );
  }
}
