import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../utils/role_helper.dart';
import 'institutions_management_screen.dart';
import 'genres_management_screen.dart';
import 'shows_management_screen.dart';
import 'performances_management_screen.dart';
import 'reviews_management_screen.dart';
import 'reports_screen.dart';
import 'users_management_screen.dart';
import 'transactions_screen.dart';

class AdminDashboard extends StatelessWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = RoleHelper.isSuperAdmin(user.roles);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dobrodošli, ${user.fullName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uloge: ${user.roles.map((r) => RoleHelper.getRoleDisplayName(r)).join(', ')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Administrativne Funkcije',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                if (isSuperAdmin)
                  _buildFeatureCard(
                    context,
                    icon: Icons.business,
                    title: 'Institucije',
                    subtitle: 'Upravljanje institucijama',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InstitutionsManagementScreen(),
                        ),
                      );
                    },
                  ),
                _buildFeatureCard(
                  context,
                  icon: Icons.theaters,
                  title: 'Predstave',
                  subtitle: 'Upravljanje predstavama',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShowsManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.event,
                  title: 'Termini',
                  subtitle: 'Upravljanje terminima',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PerformancesManagementScreen(),
                      ),
                    );
                  },
                ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.rate_review,
                    title: 'Recenzije',
                    subtitle: 'Upravljanje recenzijama',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReviewsManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.analytics,
                    title: 'Izvještaji',
                    subtitle: 'Analitika i izvještaji',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                _buildFeatureCard(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Transakcije',
                  subtitle: 'Pregled narudžbi i uplata',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransactionsScreen(),
                      ),
                    );
                  },
                ),
                if (isSuperAdmin)
                  _buildFeatureCard(
                    context,
                    icon: Icons.people,
                    title: 'Korisnici',
                    subtitle: 'Upravljanje korisnicima',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UsersManagementScreen(),
                        ),
                      );
                    },
                  ),
                if (isSuperAdmin)
                  _buildFeatureCard(
                    context,
                    icon: Icons.admin_panel_settings,
                    title: 'Žanrovi',
                    subtitle: 'Upravljanje žanrovima',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GenresManagementScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

