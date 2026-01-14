import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../shows/shows_list_screen.dart';
import '../tickets/my_tickets_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../user/my_reviews_screen.dart';

class SuperAdminKorisnikScreen extends StatelessWidget {
  final User user;

  const SuperAdminKorisnikScreen({super.key, required this.user});

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
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.star,
            title: 'Recenzije',
            subtitle: 'Pregled i ostavljanje recenzija za predstave',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyReviewsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.recommend,
            title: 'Preporuke',
            subtitle: 'Personalizovane preporuke za vas',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecommendationsScreen(),
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
