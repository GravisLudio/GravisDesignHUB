import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  double _totalEarned = 0.0;
  double _totalPaid = 0.0;
  double _balanceDue = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

      double earned = 0.0;
      for (var w in works) {
        earned += w.price;
      }

      double paid = 0.0;
      for (var p in payments) {
        paid += p.amount;
      }

      setState(() {
        _patterns = patterns;
        _works = works;
        _payments = payments;
        _totalEarned = earned;
        _totalPaid = paid;
        _balanceDue = earned - paid;
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
    if (_patterns.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin Patrones'),
          content: const Text('Primero debes crear al menos un patrón en la sección "Mis Patrones" para poder registrar un trabajo hecho.'),
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

    BeadPattern? selectedPattern;
    final TextEditingController priceCtrl = TextEditingController();

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
                      'REGISTRAR TRABAJO HECHO',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1A237E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Elegant Pattern Selector List
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
                    const SizedBox(height: 20),
                    if (selectedPattern != null) ...[
                      const Text(
                        'Precio final a cobrar por este trabajo (COP):',
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
                            decoration: const InputDecoration(
                              icon: Icon(Icons.monetization_on_rounded, color: Color(0xFF1A237E)),
                              hintText: 'Ej: 30000',
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
                            final finalPrice = double.tryParse(priceCtrl.text) ?? 0.0;
                            if (selectedPattern == null) return;
                            final record = WorkRecord(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              patternId: selectedPattern!.id,
                              patternName: selectedPattern!.name,
                              price: finalPrice,
                              createdAt: DateTime.now(),
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
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SALDO ACUMULADO PENDIENTE',
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
                'Ganado: ${formatCOP(_totalEarned)}  |  Cobrado: ${formatCOP(_totalPaid)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (_tabController.index == 0) {
                _addWorkRecord();
              } else {
                _addPaymentRecord();
              }
            },
            icon: Icon(
              _tabController.index == 0 ? Icons.add_rounded : Icons.monetization_on_rounded,
              size: 18,
            ),
            label: Text(
              _tabController.index == 0 ? 'REGISTRAR' : 'RECIBIR PAGO',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tabController.index == 0 ? const Color(0xFF1A237E) : Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _works.length,
      itemBuilder: (context, index) {
        final w = _works[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onLongPress: () => _confirmDeleteWork(w),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_on_rounded, color: Color(0xFF1A237E), size: 22),
            ),
            title: Text(
              w.patternName.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text('Fecha: ${w.createdAt.day}/${w.createdAt.month}/${w.createdAt.year} • Hecho'),
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
}
