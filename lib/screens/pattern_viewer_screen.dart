import 'package:flutter/material.dart';
import '../models/bead_pattern.dart';
import '../models/pattern_step.dart';
import '../models/bead_color.dart';
import '../widgets/bead_widget.dart';
import '../widgets/bead_board.dart';
import '../models/bead.dart';
import '../utils/currency_formatter.dart';
import '../services/storage_service.dart';
import 'add_pattern_screen.dart';

class PatternViewerScreen extends StatefulWidget {
  final BeadPattern pattern;

  const PatternViewerScreen({super.key, required this.pattern});

  @override
  State<PatternViewerScreen> createState() => _PatternViewerScreenState();
}

class _PatternViewerScreenState extends State<PatternViewerScreen> {
  int _currentStepIndex = 0;
  double _zoomScale = 1.0;

  PatternStep get _currentStep => widget.pattern.steps[_currentStepIndex];

  void _nextStep() {
    if (_currentStepIndex < widget.pattern.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  Future<void> _editPattern() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPatternScreen(existingPattern: widget.pattern),
      ),
    );
    if (result == true && mounted) {
      // Pattern was modified: pop back to home so the list refreshes.
      Navigator.pop(context, true);
    }
  }

  Future<void> _deletePattern() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Patrón'),
        content: Text('¿Estás seguro de que quieres eliminar "${widget.pattern.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (result == true) {
      await StorageService().deletePattern(widget.pattern.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // Aggregate bead counts across all steps, grouped by color value (ARGB int).
  // Returns ordered list of (BeadColor, count) sorted by count desc.
  List<MapEntry<BeadColor, int>> _materialTotals() {
    final Map<int, int> countByArgb = {};
    final Map<int, BeadColor> colorByArgb = {};
    for (final step in widget.pattern.steps) {
      for (final bead in step.beads) {
        if (bead.isEmpty || bead.beadColor == null) continue;
        final argb = bead.beadColor!.color.value;
        countByArgb[argb] = (countByArgb[argb] ?? 0) + 1;
        colorByArgb.putIfAbsent(argb, () => bead.beadColor!);
      }
    }
    final entries = countByArgb.entries
        .map((e) => MapEntry(colorByArgb[e.key]!, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  void _showMaterialSummary() {
    final totals = _materialTotals();
    final int grandTotal = totals.fold(0, (sum, e) => sum + e.value);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: Color(0xFF1A237E)),
                  const SizedBox(width: 8),
                  const Text(
                    'MATERIAL TOTAL',
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$grandTotal cuentas',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (totals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No hay cuentas en este patrón.'),
                )
              else
                ...totals.map((entry) {
                  final bc = entry.key;
                  final count = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: bc.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: bc.color.computeLuminance() > 0.7
                                  ? Colors.grey.shade400
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bc.name.isNotEmpty ? bc.name : 'Color',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.pattern.name.toUpperCase()),
            if (widget.pattern.price > 0)
              Text(
                formatCOP(widget.pattern.price),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar patrón',
            onPressed: _editPattern,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Eliminar patrón',
            onPressed: _deletePattern,
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Material total',
            onPressed: _showMaterialSummary,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepHeader(),
            Expanded(
              child: _buildBeadBoard(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF9C4).withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          Text(
            'ETAPA ${_currentStepIndex + 1} / ${widget.pattern.steps.length}',
            style: const TextStyle(
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep.instruction,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (_currentStep.note != null) ...[
            const SizedBox(height: 4),
            Text(
              _currentStep.note!,
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBeadBoard() {
    return InteractiveViewer(
      minScale: 0.3,
      maxScale: 5.0,
      scaleEnabled: true,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(1000),
      alignment: Alignment.center,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(100),
          child: BeadBoard(
            steps: widget.pattern.steps,
            currentStepIndex: _currentStepIndex,
            beadSize: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _currentStepIndex.toDouble(),
            min: 0,
            max: (widget.pattern.steps.length - 1).toDouble(),
            divisions: widget.pattern.steps.length > 1 ? widget.pattern.steps.length - 1 : 1,
            onChanged: (value) {
              setState(() {
                _currentStepIndex = value.toInt();
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentStepIndex > 0 ? _previousStep : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('ANTERIOR'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentStepIndex < widget.pattern.steps.length - 1 ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF3949AB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('SIGUIENTE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
