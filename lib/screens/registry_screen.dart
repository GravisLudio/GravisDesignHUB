import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bead_pattern.dart';
import '../models/work_record.dart';
import '../models/payment_record.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';

class RegistryScreen extends StatefulWidget {
  const RegistryScreen({super.key});

  @override
  State<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends State<RegistryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storageService = StorageService();

  List<BeadPattern> _patterns = [];
  List<WorkRecord> _works = [];
  List<PaymentRecord> _payments = [];
  bool _isLoading = true;

  double _totalHecho = 0.0;
  double _totalEntregado = 0.0;
  double _totalEarned = 0.0;
  double _totalPaid = 0.0;
  double _balanceDue = 0.0;
  String _worksFilter = 'all'; // 'all', 'hecho', 'entregado'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {}); // Rebuild to update button icon and action when switching tabs
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final patterns = await _storageService.getPatterns();
      final works = await _storageService.getWorkRecords();
      final payments = await _storageService.getPayments();

      double hecho = 0.0;
      double entregado = 0.0;
      for (var w in works) {
        if (w.status == 'hecho') {
          hecho += w.price;
        } else {
          entregado += w.price;
        }
      }

      double paid = 0.0;
      for (var p in payments) {
        paid += p.amount;
      }

      setState(() {
        _patterns = patterns;
        _works = works;
        _payments = payments;
        _totalHecho = hecho;
        _totalEntregado = entregado;
        _totalEarned = hecho + entregado;
        _totalPaid = paid;
        _balanceDue = entregado - paid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  // --- Actions ---

  Future<void> _addWorkRecord() async {
    String workType = _patterns.isEmpty ? 'generic' : 'pattern'; // 'pattern' or 'generic'
    BeadPattern? selectedPattern;
    final TextEditingController descriptionCtrl = TextEditingController(text: 'Trabajo Genérico');
    final TextEditingController priceCtrl = TextEditingController();
    final TextEditingController quantityCtrl = TextEditingController(text: '1');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      'REGISTRAR TRABAJO HECHO',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1A237E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selector de tipo de trabajo
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('POR PATRÓN'),
                            selected: workType == 'pattern',
                            onSelected: _patterns.isEmpty
                                ? null
                                : (val) {
                                    if (val) {
                                      setModalState(() {
                                        workType = 'pattern';
                                        selectedPattern = null;
                                        priceCtrl.clear();
                                      });
                                    }
                                  },
                            selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: workType == 'pattern' ? const Color(0xFF1A237E) : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('TRABAJO LIBRE'),
                            selected: workType == 'generic',
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  workType = 'generic';
                                  priceCtrl.clear();
                                });
                              }
                            },
                            selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: workType == 'generic' ? const Color(0xFF1A237E) : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (workType == 'pattern') ...[
                      const Text(
                        'Selecciona el patrón fabricado:',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _patterns.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = _patterns[index];
                            final isSelected = selectedPattern?.id == p.id;
                            return ListTile(
                              onTap: () {
                                setModalState(() {
                                  selectedPattern = p;
                                  priceCtrl.text = p.price.round().toString();
                                });
                              },
                              tileColor: isSelected ? const Color(0xFF1A237E).withOpacity(0.05) : null,
                              leading: Icon(
                                Icons.grid_on_rounded,
                                color: isSelected ? const Color(0xFF1A237E) : Colors.grey,
                              ),
                              title: Text(
                                p.name.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF1A237E) : null,
                                ),
                              ),
                              subtitle: Text('${p.steps.length} pasos • ${formatCOP(p.price)}'),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1A237E))
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (selectedPattern != null) ...[
                        const Text(
                          'Precio Unitario (COP):',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          color: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setModalState(() {}),
                              decoration: const InputDecoration(
                                icon: Icon(Icons.monetization_on_rounded, color: Color(0xFF1A237E)),
                                hintText: 'Ej: 30000',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cantidad hecha (unidades):',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          color: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: quantityCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setModalState(() {}),
                              decoration: const InputDecoration(
                                icon: Icon(Icons.tag_rounded, color: Color(0xFF1A237E)),
                                hintText: 'Ej: 1',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final uPrice = double.tryParse(priceCtrl.text) ?? 0.0;
                            final qty = int.tryParse(quantityCtrl.text) ?? 1;
                            final total = uPrice * qty;
                            return Text(
                              'Total a cobrar: ${formatCOP(total)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green.shade800,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              final finalUnitPrice = double.tryParse(priceCtrl.text) ?? 0.0;
                              final qty = int.tryParse(quantityCtrl.text) ?? 1;
                              if (selectedPattern == null) return;
                              final record = WorkRecord(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                patternId: selectedPattern!.id,
                                patternName: selectedPattern!.name,
                                price: finalUnitPrice * qty,
                                createdAt: DateTime.now(),
                                quantity: qty,
                              );
                              await _storageService.saveWorkRecord(record);
                              Navigator.pop(ctx);
                              _loadData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('REGISTRAR TRABAJO', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'Descripción / Nombre del trabajo:',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: descriptionCtrl,
                            decoration: const InputDecoration(
                              icon: Icon(Icons.description_rounded, color: Color(0xFF1A237E)),
                              hintText: 'Ej: Ajuste de manillas, Trabajo extra',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Precio Unitario (COP):',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => setModalState(() {}),
                            decoration: const InputDecoration(
                              icon: Icon(Icons.monetization_on_rounded, color: Color(0xFF1A237E)),
                              hintText: 'Ej: 30000',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cantidad hecha (unidades):',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: quantityCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => setModalState(() {}),
                            decoration: const InputDecoration(
                              icon: Icon(Icons.tag_rounded, color: Color(0xFF1A237E)),
                              hintText: 'Ej: 1',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final uPrice = double.tryParse(priceCtrl.text) ?? 0.0;
                          final qty = int.tryParse(quantityCtrl.text) ?? 1;
                          final total = uPrice * qty;
                          return Text(
                            'Total a cobrar: ${formatCOP(total)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade800,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final finalUnitPrice = double.tryParse(priceCtrl.text) ?? 0.0;
                            final qty = int.tryParse(quantityCtrl.text) ?? 1;
                            if (finalUnitPrice <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor, ingresa un precio válido.')),
                              );
                              return;
                            }
                            final record = WorkRecord(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              patternId: 'generic_work',
                              patternName: descriptionCtrl.text.trim().isNotEmpty
                                  ? descriptionCtrl.text.trim()
                                  : 'Trabajo Libre',
                              price: finalUnitPrice * qty,
                              createdAt: DateTime.now(),
                              quantity: qty,
                            );
                            await _storageService.saveWorkRecord(record);
                            Navigator.pop(ctx);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('REGISTRAR TRABAJO', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _deliverWork() async {
    final hechos = _works.where((w) => w.status == 'hecho').toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first for chronological value allocation

    if (hechos.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin Trabajo Hecho'),
          content: const Text('No hay trabajos en estado "Por Entregar" en este momento.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      return;
    }

    String deliveryType = 'all'; // 'all', 'select', 'value'
    final Map<String, bool> selectedItems = {for (var h in hechos) h.id: true};
    final TextEditingController valueCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalSelectedValue = hechos
                .where((h) => selectedItems[h.id] == true)
                .fold(0.0, (sum, item) => sum + item.price);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTREGAR TRABAJO',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF3949AB),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valor total hecho por entregar: ${formatCOP(_totalHecho)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    // Selector de tipo de entrega
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('TODO'),
                            selected: deliveryType == 'all',
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  deliveryType = 'all';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('SELECCIONAR'),
                            selected: deliveryType == 'select',
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  deliveryType = 'select';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('VALOR (\$)'),
                            selected: deliveryType == 'value',
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  deliveryType = 'value';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (deliveryType == 'all') ...[
                      const Text(
                        'Se entregarán todos los trabajos hechos acumulados. Esto pasará el saldo a "Pendiente de Pago".',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final List<Map<String, dynamic>> deliveredList = hechos.map((h) => {
                              'name': h.patternName,
                              'quantity': h.quantity,
                              'totalPrice': h.price,
                            }).toList();
                            final totalValue = _totalHecho;

                            for (var h in hechos) {
                              final updated = WorkRecord(
                                id: h.id,
                                patternId: h.patternId,
                                patternName: h.patternName,
                                price: h.price,
                                createdAt: h.createdAt,
                                status: 'entregado',
                                quantity: h.quantity,
                              );
                              await _storageService.saveWorkRecord(updated);
                            }
                            Navigator.pop(ctx);
                            await _loadData();
                            _showDeliverySuccessDialog(deliveredList, totalValue);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3949AB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ENTREGAR TODO', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else if (deliveryType == 'select') ...[
                      const Text(
                        'Selecciona las piezas a entregar:',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: hechos.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final h = hechos[index];
                            final isChecked = selectedItems[h.id] == true;
                            return CheckboxListTile(
                              value: isChecked,
                              onChanged: (val) {
                                setModalState(() {
                                  selectedItems[h.id] = val ?? false;
                                });
                              },
                              title: Text(h.patternName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(formatCOP(h.price)),
                              activeColor: const Color(0xFF3949AB),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total seleccionado: ${formatCOP(totalSelectedValue)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: totalSelectedValue <= 0
                              ? null
                              : () async {
                                  final List<Map<String, dynamic>> deliveredList = hechos
                                      .where((h) => selectedItems[h.id] == true)
                                      .map((h) => {
                                        'name': h.patternName,
                                        'quantity': h.quantity,
                                        'totalPrice': h.price,
                                      }).toList();
                                  final totalValue = totalSelectedValue;

                                  for (var h in hechos) {
                                    if (selectedItems[h.id] == true) {
                                      final updated = WorkRecord(
                                        id: h.id,
                                        patternId: h.patternId,
                                        patternName: h.patternName,
                                        price: h.price,
                                        createdAt: h.createdAt,
                                        status: 'entregado',
                                        quantity: h.quantity,
                                      );
                                      await _storageService.saveWorkRecord(updated);
                                    }
                                  }
                                  Navigator.pop(ctx);
                                  await _loadData();
                                  _showDeliverySuccessDialog(deliveredList, totalValue);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3949AB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ENTREGAR SELECCIONADOS', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Ingresa el valor total entregado (COP):',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: valueCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              icon: Icon(Icons.monetization_on_rounded, color: Color(0xFF3949AB)),
                              hintText: 'Ej: 25000',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final targetValue = double.tryParse(valueCtrl.text) ?? 0.0;
                            if (targetValue <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor, ingresa un valor válido superior a 0.')),
                              );
                              return;
                            }
                            if (targetValue > _totalHecho + 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('El valor a entregar no puede superar el total hecho (${formatCOP(_totalHecho)}).')),
                              );
                              return;
                            }

                            final List<Map<String, dynamic>> deliveredList = [];
                            final totalValue = targetValue;
                            double remainingToDeliver = targetValue;

                            for (var h in hechos) {
                              if (remainingToDeliver <= 0) break;

                              if (h.price <= remainingToDeliver + 0.01) {
                                // Deliver fully
                                deliveredList.add({
                                  'name': h.patternName,
                                  'quantity': h.quantity,
                                  'totalPrice': h.price,
                                });
                                final updated = WorkRecord(
                                  id: h.id,
                                  patternId: h.patternId,
                                  patternName: h.patternName,
                                  price: h.price,
                                  createdAt: h.createdAt,
                                  status: 'entregado',
                                  quantity: h.quantity,
                                );
                                await _storageService.saveWorkRecord(updated);
                                remainingToDeliver -= h.price;
                              } else {
                                // Split this work record
                                final double deliveredPart = remainingToDeliver;
                                final double remainingPart = h.price - deliveredPart;
                                final double fraction = deliveredPart / h.price;
                                final deliveredQty = (h.quantity * fraction).round().clamp(1, h.quantity);
                                final remainingQty = (h.quantity - deliveredQty).clamp(1, h.quantity);

                                deliveredList.add({
                                  'name': h.patternName,
                                  'quantity': deliveredQty,
                                  'totalPrice': deliveredPart,
                                });

                                // 1. Update existing to 'entregado' with deliveredPart price
                                final updatedDelivered = WorkRecord(
                                  id: h.id,
                                  patternId: h.patternId,
                                  patternName: h.patternName,
                                  price: deliveredPart,
                                  createdAt: h.createdAt,
                                  status: 'entregado',
                                  quantity: deliveredQty,
                                );
                                await _storageService.saveWorkRecord(updatedDelivered);

                                // 2. Create new 'hecho' record for the remainder
                                final newHecho = WorkRecord(
                                  id: '${h.id}_split_${DateTime.now().millisecondsSinceEpoch}',
                                  patternId: h.patternId,
                                  patternName: h.patternName,
                                  price: remainingPart,
                                  createdAt: h.createdAt.add(const Duration(milliseconds: 1)),
                                  status: 'hecho',
                                  quantity: remainingQty,
                                );
                                await _storageService.saveWorkRecord(newHecho);

                                remainingToDeliver = 0;
                              }
                            }

                            Navigator.pop(ctx);
                            await _loadData();
                            _showDeliverySuccessDialog(deliveredList, totalValue);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3949AB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ENTREGAR POR VALOR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addPaymentRecord() async {
    if (_balanceDue <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin Saldo Pendiente'),
          content: const Text('No tienes saldo pendiente por cobrar en este momento.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      return;
    }

    String paymentType = 'abono'; // 'abono' or 'completo'
    final TextEditingController amountCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTRAR PAGO RECIBIDO',
                      style: GoogleFonts.outfit(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Saldo Pendiente Actual: ${formatCOP(_balanceDue)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('ABONO PARCIAL'),
                            selected: paymentType == 'abono',
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  paymentType = 'abono';
                                  amountCtrl.clear();
                                });
                              }
                            },
                            selectedColor: Colors.green.shade100,
                            labelStyle: TextStyle(
                              color: paymentType == 'abono' ? Colors.green.shade900 : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('PAGO COMPLETO'),
                            selected: paymentType == 'completo',
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  paymentType = 'completo';
                                  amountCtrl.text = _balanceDue.round().toString();
                                });
                              }
                            },
                            selectedColor: Colors.green.shade100,
                            labelStyle: TextStyle(
                              color: paymentType == 'completo' ? Colors.green.shade900 : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Dinero Recibido (COP):',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      color: const Color(0xFFF5F5F5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          enabled: paymentType == 'abono', // Disable input for full payment
                          decoration: const InputDecoration(
                            icon: Icon(Icons.monetization_on_rounded, color: Colors.green),
                            hintText: 'Ej: 15000',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, ingresa un monto válido superior a 0.')),
                            );
                            return;
                          }
                          if (amount > _balanceDue + 10) { // Tiny buffer
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('El monto pagado no puede superar el saldo pendiente (${formatCOP(_balanceDue)}).')),
                            );
                            return;
                          }

                          final record = PaymentRecord(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            amount: amount,
                            type: paymentType,
                            createdAt: DateTime.now(),
                          );
                          await _storageService.savePayment(record);
                          Navigator.pop(ctx);
                          _loadData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('REGISTRAR PAGO', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteWork(WorkRecord work) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Registro'),
        content: Text('¿Deseas eliminar el registro contable de "${work.patternName}"? Esto restará ${formatCOP(work.price)} de tu dinero ganado.'),
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
      await _storageService.deleteWorkRecord(work.id);
      _loadData();
    }
  }

  Future<void> _confirmDeletePayment(PaymentRecord payment) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Pago'),
        content: Text('¿Deseas eliminar este registro de pago de ${formatCOP(payment.amount)}? Esto aumentará tu saldo pendiente nuevamente.'),
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
      await _storageService.deletePayment(payment.id);
      _loadData();
    }
  }

  // --- Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('📋 REGISTRO CONTABLE'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'TRABAJOS REALIZADOS', icon: Icon(Icons.grid_on_rounded, size: 20)),
            Tab(text: 'HISTORIAL DE PAGOS', icon: Icon(Icons.history_toggle_off_rounded, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Info Bar
                _buildQuickOverviewCard(),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWorksTab(),
                      _buildPaymentsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuickOverviewCard() {
    final bool isWorksTab = _tabController.index == 0;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALDO PENDIENTE (ENTREGADO)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCOP(_balanceDue),
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _balanceDue > 0 ? const Color(0xFF1A237E) : Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Por Entregar: ${formatCOP(_totalHecho)}\nEntregado: ${formatCOP(_totalEntregado)}  |  Cobrado: ${formatCOP(_totalPaid)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isWorksTab) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_totalHecho > 0) ...[
                  ElevatedButton.icon(
                    onPressed: _deliverWork,
                    icon: const Icon(Icons.local_shipping_rounded, size: 15),
                    label: const Text(
                      'ENTREGAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3949AB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (_totalEntregado > 0) ...[
                  ElevatedButton.icon(
                    onPressed: _shareDeliveredWorksReport,
                    icon: const Icon(Icons.share_rounded, size: 15),
                    label: const Text(
                      'REPORTE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                ElevatedButton.icon(
                  onPressed: _addWorkRecord,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'REGISTRAR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ],
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _addPaymentRecord,
              icon: const Icon(Icons.monetization_on_rounded, size: 18),
              label: const Text(
                'RECIBIR PAGO',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorksTab() {
    if (_works.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No hay trabajos registrados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa el botón "REGISTRAR" de arriba para añadir un patrón que hayas tejido.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final filteredWorks = _works.where((w) {
      if (_worksFilter == 'hecho') return w.status == 'hecho';
      if (_worksFilter == 'entregado') return w.status == 'entregado';
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.white,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('TODOS'),
                selected: _worksFilter == 'all',
                onSelected: (val) {
                  if (val) setState(() => _worksFilter = 'all');
                },
                selectedColor: const Color(0xFF1A237E).withOpacity(0.12),
                labelStyle: TextStyle(
                  color: _worksFilter == 'all' ? const Color(0xFF1A237E) : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('POR ENTREGAR (HECHO)'),
                selected: _worksFilter == 'hecho',
                onSelected: (val) {
                  if (val) setState(() => _worksFilter = 'hecho');
                },
                selectedColor: Colors.amber.shade100,
                labelStyle: TextStyle(
                  color: _worksFilter == 'hecho' ? Colors.amber.shade900 : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('ENTREGADOS'),
                selected: _worksFilter == 'entregado',
                onSelected: (val) {
                  if (val) setState(() => _worksFilter = 'entregado');
                },
                selectedColor: Colors.blue.shade100,
                labelStyle: TextStyle(
                  color: _worksFilter == 'entregado' ? Colors.blue.shade900 : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        // Works List
        Expanded(
          child: filteredWorks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No hay registros que coincidan',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredWorks.length,
                  itemBuilder: (context, index) {
                    final w = filteredWorks[index];
                    final isHecho = w.status == 'hecho';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onLongPress: () => _confirmDeleteWork(w),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isHecho ? Colors.amber.shade50 : const Color(0xFF1A237E).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isHecho ? Icons.build_circle_rounded : Icons.check_circle_rounded,
                            color: isHecho ? Colors.amber.shade800 : const Color(0xFF1A237E),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          '${w.patternName.toUpperCase()}${w.quantity > 1 ? ' (x${w.quantity})' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                'Fecha: ${w.createdAt.day}/${w.createdAt.month}/${w.createdAt.year}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isHecho ? Colors.amber.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isHecho ? Colors.amber.shade200 : Colors.blue.shade200,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  isHecho ? 'HECHO' : 'ENTREGADO',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: isHecho ? Colors.amber.shade900 : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatCOP(w.price),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: const Color(0xFF1A237E),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _confirmDeleteWork(w),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payment_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No hay pagos registrados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa el botón "RECIBIR PAGO" de arriba para abonar o saldar tus cuentas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final isComplete = p.type == 'completo';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onLongPress: () => _confirmDeletePayment(p),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isComplete ? Icons.offline_pin_rounded : Icons.monetization_on_outlined,
                color: Colors.green,
                size: 22,
              ),
            ),
            title: Text(
              isComplete ? 'PAGO COMPLETO' : 'ABONO PARCIAL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green.shade900,
              ),
            ),
            subtitle: Text('Fecha: ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '- ${formatCOP(p.amount)}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDeletePayment(p),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeliverySuccessDialog(List<Map<String, dynamic>> deliveredItems, double totalDeliveredValue) {
    final GlobalKey repaintKey = GlobalKey();
    final formattedDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
    
    // Build the shareable text
    final buffer = StringBuffer();
    buffer.writeln("📋 *REPORTE DE ENTREGA - DESIGNHUB*");
    buffer.writeln("📅 Fecha: $formattedDate");
    buffer.writeln("");
    buffer.writeln("*Detalle de Trabajos Entregados:*");
    buffer.writeln("----------------------------------");
    for (var item in deliveredItems) {
      final name = item['name'] as String;
      final qty = item['quantity'] as int;
      final price = item['totalPrice'] as double;
      buffer.writeln("• ${qty}x ${name.toUpperCase()} - ${formatCOP(price)}");
    }
    buffer.writeln("----------------------------------");
    buffer.writeln("💰 *Monto Entregado:* ${formatCOP(totalDeliveredValue)}");
    buffer.writeln("💵 *Saldo Pendiente por Cobrar:* ${formatCOP(_balanceDue)}");
    buffer.writeln("");
    buffer.writeln("*¡Gracias por tu trabajo!*");

    final reportText = buffer.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Text(
                '¡Entrega Registrada!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El trabajo ha sido marcado como entregado en tu contabilidad.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: repaintKey,
                    child: _buildReceiptWidget(
                      title: 'Comprobante de Entrega',
                      items: deliveredItems,
                      totalValue: totalDeliveredValue,
                      balanceDue: _balanceDue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _shareReceipt(
                  key: repaintKey,
                  text: reportText,
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('ENVIAR A WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _shareDeliveredWorksReport() {
    final deliveredList = _works.where((w) => w.status == 'entregado').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

    if (deliveredList.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin Trabajos Entregados'),
          content: const Text('No tienes ningún trabajo registrado como "Entregado" para generar un reporte.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      return;
    }

    final formattedDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
    
    // Build the shareable text
    final buffer = StringBuffer();
    buffer.writeln("📋 *REPORTE HISTÓRICO DE ENTREGAS - DESIGNHUB*");
    buffer.writeln("📅 Generado: $formattedDate");
    buffer.writeln("");
    buffer.writeln("*Trabajos Registrados como Entregados:*");
    buffer.writeln("----------------------------------");
    for (var item in deliveredList) {
      final name = item.patternName;
      final qty = item.quantity;
      final price = item.price;
      buffer.writeln("• ${qty}x ${name.toUpperCase()} - ${formatCOP(price)} (${item.createdAt.day}/${item.createdAt.month})");
    }
    buffer.writeln("----------------------------------");
    buffer.writeln("💰 *Total Entregado:* ${formatCOP(_totalEntregado)}");
    buffer.writeln("💸 *Total Cobrado:* ${formatCOP(_totalPaid)}");
    buffer.writeln("💵 *Saldo Pendiente por Cobrar:* ${formatCOP(_balanceDue)}");
    buffer.writeln("");
    buffer.writeln("*¡Gracias por tu trabajo!*");

    final reportText = buffer.toString();
    final GlobalKey repaintKey = GlobalKey();

    final List<Map<String, dynamic>> items = deliveredList.map((item) => {
      'name': item.patternName,
      'quantity': item.quantity,
      'totalPrice': item.price,
      'date': "${item.createdAt.day}/${item.createdAt.month}",
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.assignment_turned_in_rounded, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Text(
                'Reporte de Entregas',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aquí tienes el desglose histórico de tus entregas y el saldo actual.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: repaintKey,
                    child: _buildReceiptWidget(
                      title: 'Reporte de Entregas',
                      items: items,
                      totalValue: _totalEntregado,
                      balanceDue: _balanceDue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _shareReceipt(
                  key: repaintKey,
                  text: reportText,
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('ENVIAR A WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReceiptWidget({
    required String title,
    required List<Map<String, dynamic>> items,
    required double totalValue,
    required double balanceDue,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Bar
          Container(
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DESIGNHUB',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1A237E),
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF1A237E),
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const Divider(height: 24, thickness: 1),
                
                // Item List Title
                const Text(
                  'DETALLE DE TRABAJOS:',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Items Loop
                ...items.map((item) {
                  final name = item['name'] as String;
                  final qty = item['quantity'] as int;
                  final price = item['totalPrice'] as double;
                  final dateStr = item['date'] != null ? ' (${item['date']})' : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${qty}x ${name.toUpperCase()}$dateStr',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatCOP(price),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                const Divider(height: 24, thickness: 1),
                
                // Summary Block
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monto de Entrega:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      formatCOP(totalValue),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saldo Pendiente por Cobrar:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      formatCOP(balanceDue),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: balanceDue > 0 ? const Color(0xFFD32F2F) : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 24, thickness: 1),
                
                // Footer Note
                Center(
                  child: Column(
                    children: [
                      Text(
                        '¡Gracias por tu gran trabajo!',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Comprobante digital generado desde DesignHub.',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<File?> _captureWidgetToImage(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 3.0); // High definition PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/comprobante_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      debugPrint("Error al capturar recibo: $e");
      return null;
    }
  }

  Future<void> _shareReceipt({
    required GlobalKey key,
    required String text,
  }) async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final imageFile = await _captureWidgetToImage(key);
    
    // Dismiss loading indicator
    if (mounted) Navigator.pop(context);

    if (imageFile != null) {
      await Share.shareXFiles(
        [XFile(imageFile.path)],
        text: text,
      );
    } else {
      // Fallback to text sharing if image fails
      await Share.share(text);
    }
  }
}
