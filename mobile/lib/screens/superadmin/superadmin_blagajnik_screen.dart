import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../blagajnik/qr_scanner_screen.dart';
import 'blagajnik_scanned_tickets_screen.dart';

class SuperAdminBlagajnikScreen extends StatelessWidget {
  final User user;

  const SuperAdminBlagajnikScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Tab body (HomeScreen already provides AppBar + BottomNav)
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.qr_code_scanner,
            title: 'QR Skeniranje',
            subtitle: 'Skeniranje QR kodova za ulaz',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.payment,
            title: 'Pregled karata',
            subtitle: 'Pregled svih karata',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlagajnikScannedTicketsScreen(
                    user: user,
                    isSuperAdmin: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
