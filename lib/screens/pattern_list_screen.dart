import 'package:flutter/material.dart';
import '../models/bead_pattern.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';
import 'add_pattern_screen.dart';
import 'pattern_viewer_screen.dart';

class PatternListScreen extends StatefulWidget {
  const PatternListScreen({super.key});

  @override
  State<PatternListScreen> createState() => _PatternListScreenState();
}

class _PatternListScreenState extends State<PatternListScreen> {
  final StorageService _storageService = StorageService();
  List<BeadPattern> _patterns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatterns();
  }

  Future<void> _loadPatterns() async {
    setState(() => _isLoading = true);
    try {
      final patterns = await _storageService.getPatterns();
      setState(() {
        _patterns = patterns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar patrones: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('📐 MIS PATRONES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatterns,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              const Color(0xFFF0F2F5),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _patterns.isEmpty
                ? _buildEmptyState()
                : _buildPatternList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPatternScreen()),
          );
          if (result == true) {
            _loadPatterns();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('NUEVO PATRÓN', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(Icons.auto_awesome_mosaic_rounded, size: 80, color: Theme.of(context).primaryColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'Aún no tienes patrones',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            Text(
              '¡Comienza tu primera creación de Miyuki presionando el botón de abajo!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _patterns.length,
      itemBuilder: (context, index) {
        final pattern = _patterns[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatternViewerScreen(pattern: pattern),
                  ),
                );
                if (result == true) {
                  _loadPatterns();
                }
              },
              onLongPress: () => _confirmDelete(pattern),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.grid_on_rounded, color: Theme.of(context).primaryColor, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pattern.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${pattern.steps.length} pasos • ${pattern.price > 0 ? formatCOP(pattern.price) : "Sin precio"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BeadPattern pattern) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Patrón'),
        content: Text('¿Estás seguro de que quieres eliminar "${pattern.name}"?'),
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
      await _storageService.deletePattern(pattern.id);
      _loadPatterns();
    }
  }
}
