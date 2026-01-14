import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../admin/shows_management_screen.dart';
import '../admin/performances_management_screen.dart';
import '../admin/reviews_management_screen.dart';
import '../superadmin/admin_transactions_screen.dart';

class InstitutionAdminAdminScreen extends StatelessWidget {
  final User user;

  const InstitutionAdminAdminScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Tab body (HomeScreen already provides AppBar + BottomNav)
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.event,
            title: 'Upravljanje Predstavama',
            subtitle: 'Dodavanje, uređivanje i brisanje predstava za vašu instituciju',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShowsManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.calendar_today,
            title: 'Upravljanje Terminima',
            subtitle: 'Dodavanje, uređivanje i brisanje termina za vašu instituciju',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerformancesManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.payment,
            title: 'Transakcije',
            subtitle: 'Pregled svih narudžbi za vašu instituciju',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminTransactionsScreen(
                    user: user,
                    isSuperAdmin: false,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.star,
            title: 'Upravljanje Recenzijama',
            subtitle: 'Pregled i upravljanje recenzijama za vašu instituciju',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReviewsManagementScreen(),
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

