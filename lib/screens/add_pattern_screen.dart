import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/bead_pattern.dart';
import '../models/pattern_step.dart';
import '../models/bead_color.dart';
import '../models/bead.dart';
import '../services/storage_service.dart';
import '../widgets/bead_widget.dart';
import '../widgets/bead_board.dart';

class AddPatternScreen extends StatefulWidget {
  final BeadPattern? existingPattern;

  const AddPatternScreen({super.key, this.existingPattern});

  @override
  State<AddPatternScreen> createState() => _AddPatternScreenState();
}

class _AddPatternScreenState extends State<AddPatternScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<StepInput> _steps = [];
  final StorageService _storageService = StorageService();
  final TransformationController _previewController = TransformationController();
  String? _editingId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPattern;
    if (existing != null) {
      _editingId = existing.id;
      _nameController.text = existing.name;
      for (final step in existing.steps) {
        final stepInput = StepInput();
        stepInput.noteController.text = step.note ?? '';
        // Aggregate beads by color into BeadCounts
        final Map<int, BeadCount> grouped = {};
        for (final bead in step.beads) {
          if (bead.isEmpty || bead.beadColor == null) continue;
          final argb = bead.beadColor!.color.value;
          if (grouped.containsKey(argb)) {
            grouped[argb]!.count++;
          } else {
            grouped[argb] = BeadCount(color: bead.beadColor!.color, count: 1);
          }
        }
        stepInput.beadCounts = grouped.values.toList();
        _steps.add(stepInput);
      }
      if (_steps.isEmpty) _steps.add(StepInput());
    } else {
      _steps.add(StepInput());
    }
  }

  // Find the closest preset BeadColor to a given Color (RGB Euclidean distance).
  // Returns the matched preset, or a fallback "Color XXXXXX" BeadColor if no preset
  // is within a reasonable threshold.
  BeadColor _matchPresetColor(Color color) {
    BeadColor? closest;
    double bestDist = double.infinity;
    for (final preset in BeadColor.values) {
      final dr = preset.color.red - color.red;
      final dg = preset.color.green - color.green;
      final db = preset.color.blue - color.blue;
      final dist = (dr * dr + dg * dg + db * db).toDouble();
      if (dist < bestDist) {
        bestDist = dist;
        closest = preset;
      }
    }
    // If too far from any preset (>120 per channel avg), fall back to hex name
    if (closest == null || bestDist > 120 * 120 * 3) {
      final hex = color.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2);
      return BeadColor('', 'Color $hex', color);
    }
    return closest;
  }

  String _pluralize(String singular) {
    // "blanca" -> "blancas", "negro" -> "negros"
    if (singular.endsWith('a') || singular.endsWith('o')) return '${singular}s';
    if (singular.endsWith('e') || singular.endsWith('í')) return '${singular}s';
    return '${singular}s';
  }

  // Friendly bead-name plural by color name.
  // "Blanco"->"blancas", "Negro"->"negras", "Piel"->"pieles", "Rojo"->"rojas", etc.
  String _instructionNameFor(BeadColor bc, int count) {
    final Map<String, String> singularFem = {
      'Blanco': 'blanca',
      'Negro': 'negra',
      'Piel': 'piel',
      'Verde': 'verde',
      'Café': 'café',
      'Rojo': 'roja',
      'Amarillo': 'amarilla',
      'Naranja': 'naranja',
      'Morado': 'morada',
      'Rosado': 'rosada',
      'Azul': 'azul',
      'Dorado': 'dorada',
    };
    final base = singularFem[bc.name] ?? bc.name.toLowerCase();
    if (count == 1) return base;
    // Pluralize
    if (base.endsWith('z')) return '${base.substring(0, base.length - 1)}ces';
    if (base.endsWith('í') || base.endsWith('é') || base.endsWith('á') ||
        base.endsWith('ó') || base.endsWith('ú')) return '${base}s';
    if (base.endsWith('e') || base.endsWith('a') || base.endsWith('o')) return '${base}s';
    return '${base}es';
  }

  List<PatternStep> _getPatternSteps() {
    final List<PatternStep> patternSteps = [];
    for (var stepInput in _steps) {
      final List<Bead> beads = [];
      String instruction = "";
      for (var bc in stepInput.beadCounts) {
        final beadColor = _matchPresetColor(bc.color);
        for (int i = 0; i < bc.count; i++) {
          beads.add(Bead.colored(beadColor));
        }
        if (instruction.isNotEmpty) instruction += ", ";
        instruction += "${bc.count} ${_instructionNameFor(beadColor, bc.count)}";
      }

      patternSteps.add(PatternStep(
        instruction: instruction,
        note: stepInput.noteController.text.isNotEmpty ? stepInput.noteController.text : null,
        beads: beads,
      ));
    }
    return patternSteps;
  }

  void _addStep() {
    setState(() {
      _steps.add(StepInput());
    });
  }

  void _removeStep(int index) {
    if (_steps.length > 1) {
      setState(() {
        _steps.removeAt(index);
      });
    }
  }

  void _addBeadToStep(int stepIndex, Color color) {
    setState(() {
      final step = _steps[stepIndex];
      final existingIndex = step.beadCounts.indexWhere((bc) => bc.color.value == color.value);
      if (existingIndex != -1) {
        step.beadCounts[existingIndex].count++;
      } else {
        step.beadCounts.add(BeadCount(color: color, count: 1));
      }
    });
  }

  void _updateBeadCount(int stepIndex, int beadIndex, int delta) {
    setState(() {
      final step = _steps[stepIndex];
      step.beadCounts[beadIndex].count += delta;
      if (step.beadCounts[beadIndex].count <= 0) {
        step.beadCounts.removeAt(beadIndex);
      }
    });
  }

  Future<void> _pickColor(int stepIndex) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECCIONA UN COLOR',
                style: TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: BeadColor.values.map((preset) {
                  return GestureDetector(
                    onTap: () {
                      _addBeadToStep(stepIndex, preset.color);
                      Navigator.pop(ctx);
                    },
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: preset.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: preset.color.computeLuminance() > 0.7
                                    ? Colors.grey.shade400
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 3,
                                  offset: const Offset(1, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.name,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCELAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePattern() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un nombre para el patrón')),
      );
      return;
    }

    final patternSteps = _getPatternSteps();

    if (patternSteps.every((s) => s.beads.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una cuenta en algún paso')),
      );
      return;
    }

    final pattern = BeadPattern(
      id: _editingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      steps: patternSteps,
      createdAt: widget.existingPattern?.createdAt ?? DateTime.now(),
      columns: patternSteps.length,
    );

    await _storageService.savePattern(pattern);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? 'EDITAR PATRÓN' : 'NUEVO PATRÓN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _savePattern,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 24),
            const Text(
              'VISTA PREVIA DEL TEJIDO',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildPreview(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PASOS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                ),
                Text('${_steps.length} ${_steps.length == 1 ? 'paso' : 'pasos'}'),
              ],
            ),
            const SizedBox(height: 12),
            ..._steps.asMap().entries.map((entry) => _buildStepItem(entry.key, entry.value)),
            const SizedBox(height: 20),
            _buildAddStepButton(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savePattern,
        icon: const Icon(Icons.save),
        label: const Text('GUARDAR'),
      ),
    );
  }

  // Preview area: drag to pan, mouse wheel to zoom (only when hovering).
  // Scroll events are consumed via PointerSignalResolver so the parent
  // SingleChildScrollView does NOT scroll when wheel is over the preview.
  Widget _buildPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive height: ~30% of screen height, min 200, max 320.
        final screenHeight = MediaQuery.of(context).size.height;
        final double previewHeight = screenHeight * 0.30;
        final double clampedHeight =
            previewHeight.clamp(200.0, 320.0).toDouble();
        return Container(
          height: clampedHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.hardEdge,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  // Consume the event so the outer page does not scroll.
                  GestureBinding.instance.pointerSignalResolver
                      .register(event, (PointerSignalEvent ev) {
                    final pe = ev as PointerScrollEvent;
                    final delta = pe.scrollDelta.dy;
                    // Scroll up (negative delta) -> zoom in. Down -> zoom out.
                    final double factor = delta < 0 ? 1.1 : (1 / 1.1);
                    final Matrix4 m = _previewController.value.clone();
                    final Offset focal = pe.localPosition;
                    m
                      ..translate(focal.dx, focal.dy)
                      ..scale(factor)
                      ..translate(-focal.dx, -focal.dy);
                    // Clamp scale between 0.3 and 5.0
                    final double currentScale = m.getMaxScaleOnAxis();
                    if (currentScale < 0.3 || currentScale > 5.0) return;
                    _previewController.value = m;
                  });
                }
              },
              child: InteractiveViewer(
                transformationController: _previewController,
                scaleEnabled: false, // we handle zoom manually
                panEnabled: true,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: BeadBoard(
                    steps: _getPatternSteps(),
                    currentStepIndex: _steps.length - 1,
                    beadSize: 30,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            icon: Icon(Icons.palette),
            hintText: 'Nombre del patrón (ej: HELLO KITTY)',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(int index, StepInput step) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Paso ${index + 1}',
                    style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
                  ),
                ),
                if (_steps.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeStep(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('AGREGAR CUENTAS:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...step.beadCounts.asMap().entries.map((bcEntry) => _buildBeadControl(index, bcEntry.key, bcEntry.value)),
                  _buildAddColorButton(index),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: step.noteController,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeadControl(int stepIndex, int beadIndex, BeadCount bc) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          BeadWidget(bead: Bead.colored(BeadColor('', '', bc.color)), size: 30),
          const SizedBox(height: 4),
          Text('${bc.count}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => _updateBeadCount(stepIndex, beadIndex, -1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => _updateBeadCount(stepIndex, beadIndex, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddColorButton(int stepIndex) {
    return GestureDetector(
      onTap: () => _pickColor(stepIndex),
      child: Container(
        width: 60,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A237E), style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: Color(0xFF1A237E)),
            SizedBox(height: 4),
            Text('COLOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStepButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addStep,
        icon: const Icon(Icons.add),
        label: const Text('AGREGAR PASO'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF1A237E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class StepInput {
  List<BeadCount> beadCounts = [];
  final TextEditingController noteController = TextEditingController();
}

class BeadCount {
  Color color;
  int count;
  BeadCount({required this.color, this.count = 1});
}
