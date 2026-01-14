import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../utils/role_helper.dart';
import 'user/user_dashboard.dart';
import 'shows/shows_list_screen.dart';
import 'tickets/my_tickets_screen.dart';
import 'profile/edit_profile_screen.dart';
import 'superadmin/superadmin_home_screen.dart';
import 'superadmin/superadmin_admin_screen.dart';
import 'superadmin/superadmin_blagajnik_screen.dart';
import 'superadmin/superadmin_korisnik_screen.dart';
import 'admin/institution_admin_admin_screen.dart';
import 'admin/institution_admin_blagajnik_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService.instance; // Koristi singleton
  int _selectedIndex = 0;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odjava'),
        content: const Text('Da li ste sigurni da želite da se odjavite?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odjavi se'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }


  List<BottomNavigationBarItem> _buildNavItems() {
    final user = _authService.currentUser;
    if (user == null) return [];

    final items = <BottomNavigationBarItem>[];

    if (RoleHelper.isSuperAdmin(user.roles)) {
      // SuperAdmin ima 4 tabova: Home, Administratori, Blagajnik, Korisnik
      items.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Administratori',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale),
          label: 'Blagajnik',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Korisnik',
        ),
      ]);
    } else if (RoleHelper.isAdmin(user.roles)) {
      // Administrator institucije: isti koncept kao SuperAdmin (Administratori/Blagajnik/Korisnik),
      // ali bez superadmin home/opcija i sa automatskim ograničenjem na svoju instituciju.
      items.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Administratori',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale),
          label: 'Blagajnik',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Korisnik',
        ),
      ]);
    } else if (RoleHelper.isBlagajnik(user.roles)) {
      // Blagajnik institucije: 2 taba (Blagajnik/Korisnik), bez administratorskih opcija.
      items.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale),
          label: 'Blagajnik',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Korisnik',
        ),
      ]);
    } else {
      items.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Početna',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Predstave',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.confirmation_number),
          label: 'Moje Karte',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ]);
    }

    return items;
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPageForIndex(int index) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (RoleHelper.isSuperAdmin(user.roles)) {
      // SuperAdmin ima 4 tabova: Home, Administratori, Blagajnik, Korisnik
      switch (index) {
        case 0:
          // Home - superadministratorske funkcionalnosti
          return SuperAdminHomeScreen(user: user);
        case 1:
          // Administratori - administratorske funkcionalnosti svih institucija
          return SuperAdminAdminScreen(user: user);
        case 2:
          // Blagajnik - blagajničke funkcionalnosti svih institucija
          return SuperAdminBlagajnikScreen(user: user);
        case 3:
          // Korisnik - korisničke funkcionalnosti
          return SuperAdminKorisnikScreen(user: user);
        default:
          return SuperAdminHomeScreen(user: user);
      }
    } else if (RoleHelper.isAdmin(user.roles)) {
      // Administrator institucije: Administratori / Blagajnik / Korisnik (kao superadmin, ali scope=institucija)
      switch (index) {
        case 0:
          return InstitutionAdminAdminScreen(user: user);
        case 1:
          return InstitutionAdminBlagajnikScreen(user: user);
        case 2:
          return SuperAdminKorisnikScreen(user: user);
        default:
          return InstitutionAdminAdminScreen(user: user);
      }
    } else if (RoleHelper.isBlagajnik(user.roles)) {
      // Blagajnik institucije: Blagajnik / Korisnik
      switch (index) {
        case 0:
          return InstitutionAdminBlagajnikScreen(user: user);
        case 1:
          return SuperAdminKorisnikScreen(user: user);
        default:
          return InstitutionAdminBlagajnikScreen(user: user);
      }
    } else {
      // Regular User navigation
      switch (index) {
        case 0:
          return UserDashboard(user: user);
        case 1:
          return const ShowsListScreen();
        case 2:
          return const MyTicketsScreen();
        case 3:
          return UserDashboard(user: user); // Profile
        default:
          return UserDashboard(user: user);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    // Obični korisnik (samo user funkcionalnosti) ne treba imati donje tabove.
    if (user != null &&
        !RoleHelper.isSuperAdmin(user.roles) &&
        !RoleHelper.isAdmin(user.roles) &&
        !RoleHelper.isBlagajnik(user.roles)) {
      return UserDashboard(user: user);
    }

    final navItems = _buildNavItems();
    final safeIndex = (navItems.isNotEmpty && _selectedIndex < navItems.length) ? _selectedIndex : 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        title: Builder(
          builder: (context) {
            final w = MediaQuery.sizeOf(context).width;
            final maxLogoWidth = (w * 0.62).clamp(180.0, 420.0);
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLogoWidth),
              child: SizedBox(
                height: 36,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.theaters, size: 28);
                  },
                ),
              ),
            );
          },
        ),
        actions: [
          // User info
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  user.firstName,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          // Logout
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'profile') {
                _showProfileDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Profil'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Odjavi se', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _getPageForIndex(safeIndex),
      bottomNavigationBar: navItems.isNotEmpty
          ? BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: _onNavItemTapped,
              type: BottomNavigationBarType.fixed,
              items: navItems,
            )
          : null,
    );
  }

  void _showProfileDialog() {
    final user = _authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Korisnički Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow(Icons.person, 'Ime', user.fullName),
            const SizedBox(height: 8),
            _buildProfileRow(Icons.email, 'Email', user.email),
            const SizedBox(height: 8),
            _buildProfileRow(
              Icons.verified_user,
              'Uloge',
              user.roles.map((r) => RoleHelper.getRoleDisplayName(r)).join(', '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zatvori'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Zatvori dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(user: user),
                ),
              ).then((updatedUser) {
                if (updatedUser != null) {
                  // Refresh user data if profile was updated
                  _authService.refreshUser().then((_) {
                    setState(() {}); // Refresh UI
                  });
                }
              });
            },
            icon: const Icon(Icons.edit),
            label: const Text('Uredi'),
            // style preuzet iz shared ThemeHelper
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

