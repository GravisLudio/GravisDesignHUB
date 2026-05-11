import 'bead_color.dart';

class Bead {
  final BeadColor? beadColor;
  final bool isEmpty;

  Bead({this.beadColor, this.isEmpty = false});

  factory Bead.empty() => Bead(isEmpty: true);
  factory Bead.colored(BeadColor color) => Bead(beadColor: color);

  Map<String, dynamic> toJson() => {
    'beadColor': beadColor?.toJson(),
    'isEmpty': isEmpty,
  };

  factory Bead.fromJson(Map<String, dynamic> json) {
    return Bead(
      beadColor: json['beadColor'] != null ? BeadColor.fromJson(json['beadColor']) : null,
      isEmpty: json['isEmpty'] ?? false,
    );
  }
}
