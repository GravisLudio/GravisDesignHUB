import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/work_record.dart';
import '../models/payment_record.dart';
import '../services/storage_service.dart';
import '../utils/currency_formatter.dart';
import 'pattern_list_screen.dart';
import 'registry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  bool _isLoading = true;

  double _totalEarned = 0.0;
  double _totalPaid = 0.0;
  double _balanceDue = 0.0;
  List<dynamic> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final works = await _storageService.getWorkRecords();
      final payments = await _storageService.getPayments();

      double earned = 0.0;
      for (var work in works) {
        earned += work.price;
      }

      double paid = 0.0;
      for (var p in payments) {
        paid += p.amount;
      }

      // Merge and sort activity
      final List<dynamic> activity = [];
      activity.addAll(works);
      activity.addAll(payments);
      activity.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _totalEarned = earned;
        _totalPaid = paid;
        _balanceDue = earned - paid;
        _recentActivity = activity.take(3).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos del tablero: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCloud = _storageService.isFirebaseAvailable;
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          'GRAVISDESIGNHUB',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Firebase Status Banner
                    _buildStatusBanner(isCloud),

                    // Beautiful Top Stats Header
                    _buildBalanceCard(primaryColor, secondaryColor),

                    const SizedBox(height: 24),

                    // Quick Options Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'MENÚ PRINCIPAL',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMainMenuOptions(),

                    const SizedBox(height: 28),

                    // Recent Activity Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'ACTIVIDAD RECIENTE',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentActivityList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusBanner(bool isCloud) {
    return Container(
      width: double.infinity,
      color: isCloud ? Colors.green.shade50 : Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCloud ? Icons.cloud_done_rounded : Icons.offline_pin_rounded,
            color: isCloud ? Colors.green.shade700 : Colors.amber.shade800,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCloud
                  ? 'Conectado a la nube. Sincronización en tiempo real activa.'
                  : 'Modo local activo. Ejecuta "flutterfire configure" para activar la nube.',
              style: TextStyle(
                fontSize: 12,
                color: isCloud ? Colors.green.shade900 : Colors.amber.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(Color primaryColor, Color secondaryColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withBlue(160)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SALDO PENDIENTE (ACUMULADO)',
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatCOP(_balanceDue),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL GANADO',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCOP(_totalEarned),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL COBRADO',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCOP(_totalPaid),
                        style: GoogleFonts.outfit(
                          color: secondaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMainMenuOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Mis Patrones Option
          Expanded(
            child: _buildMenuCard(
              title: 'MIS PATRONES',
              subtitle: 'Crea y visualiza tus diseños Miyuki',
              icon: Icons.palette_rounded,
              color: const Color(0xFFE8EAF6),
              iconColor: const Color(0xFF1A237E),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PatternListScreen()),
                );
                _loadDashboardData();
              },
            ),
          ),
          const SizedBox(width: 16),
          // Registro Contable Option
          Expanded(
            child: _buildMenuCard(
              title: 'REGISTRO',
              subtitle: 'Trabajos, abonos y cobros acumulados',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFFFF8E1),
              iconColor: const Color(0xFFFFB300),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegistryScreen()),
                );
                _loadDashboardData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    if (_recentActivity.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Aún no hay actividad contable',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentActivity.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
        itemBuilder: (context, index) {
          final item = _recentActivity[index];
          if (item is WorkRecord) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.grid_on_rounded, color: Colors.indigo, size: 20),
              ),
              title: Text(
                'TRABAJO: ${item.patternName.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                '${item.createdAt.day}/${item.createdAt.month} • Hecho por ti',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              trailing: Text(
                '+ ${formatCOP(item.price)}',
                style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
          } else if (item is PaymentRecord) {
            final isComplete = item.type == 'completo';
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isComplete ? Icons.offline_pin_rounded : Icons.monetization_on_outlined,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: Text(
                isComplete ? 'PAGO COMPLETO RECIBIDO' : 'ABONO RECIBIDO',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                '${item.createdAt.day}/${item.createdAt.month} • Recibido',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              trailing: Text(
                '- ${formatCOP(item.amount)}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
