import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../utils/role_helper.dart';
import 'qr_scanner_screen.dart';
import '../shows/shows_list_screen.dart';
import '../tickets/my_tickets_screen.dart';
import '../superadmin/blagajnik_scanned_tickets_screen.dart';
import '../superadmin/admin_transactions_screen.dart';

class BlagajnikDashboard extends StatelessWidget {
  final User user;

  const BlagajnikDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              width: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.theaters, size: 28);
              },
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SApplauz',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                user.firstName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (RoleHelper.isSuperAdmin(user.roles) ||
                RoleHelper.isAdmin(user.roles) ||
                RoleHelper.isBlagajnik(user.roles)) ...[
              _buildFeatureCard(
                context,
                icon: Icons.qr_code_scanner,
                title: 'QR Validacija',
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
                title: RoleHelper.isBlagajnik(user.roles) ? 'Pregled karata' : 'Transakcije',
                subtitle: RoleHelper.isBlagajnik(user.roles)
                    ? 'Pregled skeniranih karata'
                    : 'Pregled svih narudžbi',
                onTap: () {
                  if (RoleHelper.isBlagajnik(user.roles)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlagajnikScannedTicketsScreen(
                          user: user,
                          isSuperAdmin: false,
                        ),
                      ),
                    );
                  } else if (RoleHelper.isAdmin(user.roles) || RoleHelper.isSuperAdmin(user.roles)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminTransactionsScreen(
                          user: user,
                          isSuperAdmin: RoleHelper.isSuperAdmin(user.roles),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                context,
                icon: Icons.event,
                title: 'Predstave',
                subtitle: 'Pregled predstava i repertoara',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShowsListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                context,
                icon: Icons.confirmation_number,
                title: 'Moje Karte',
                subtitle: 'Pregled kupljenih karata',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyTicketsScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
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




