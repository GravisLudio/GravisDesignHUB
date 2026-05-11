import 'package:flutter/material.dart';
import '../models/bead_pattern.dart';
import '../services/storage_service.dart';
import 'add_pattern_screen.dart';
import 'pattern_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      appBar: AppBar(
        title: const Text('MIS PATRONES'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patterns.isEmpty
              ? _buildEmptyState()
              : _buildPatternList(),
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
        icon: const Icon(Icons.add),
        label: const Text('NUEVO PATRÓN'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.palette_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes patrones guardados',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text('¡Presiona el botón + para empezar!'),
        ],
      ),
    );
  }

  Widget _buildPatternList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patterns.length,
      itemBuilder: (context, index) {
        final pattern = _patterns[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(Icons.grid_on, color: Theme.of(context).primaryColor),
            ),
            title: Text(
              pattern.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${pattern.steps.length} pasos • ${pattern.createdAt.day}/${pattern.createdAt.month}/${pattern.createdAt.year}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatternViewerScreen(pattern: pattern),
                ),
              );
            },
            onLongPress: () => _confirmDelete(pattern),
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
