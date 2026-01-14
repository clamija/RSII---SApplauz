import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../admin/institutions_management_screen.dart';
import '../admin/users_management_screen.dart';
import '../admin/genres_management_screen.dart';

class SuperAdminHomeScreen extends StatelessWidget {
  final User user;

  const SuperAdminHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Body-only: HomeScreen već prikazuje AppBar (logo + username)
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.business,
            title: 'Upravljanje Institucijama',
            subtitle: 'Dodavanje, uređivanje i brisanje institucija',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InstitutionsManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.people,
            title: 'Upravljanje Korisnicima',
            subtitle: 'Dodavanje, uređivanje korisnika i dodjeljivanje uloga',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsersManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.category,
            title: 'Upravljanje Žanrovima',
            subtitle: 'Dodavanje i uređivanje žanrova predstava',
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

