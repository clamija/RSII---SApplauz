import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../utils/role_helper.dart';
import 'admin/institution_admin_admin_screen.dart';
import 'superadmin/superadmin_home_screen.dart';
import 'superadmin/superadmin_admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

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
      await globalAuthService.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _getPageForIndex(int index) {
    final user = globalAuthService.currentUser;
    if (user == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Učitavanje korisničkih podataka...'),
          ],
        ),
      );
    }

    // Napomena: Backend već blokira login za Blagajnika i Korisnika na desktop,
    // ali ovo je dodatna zaštita u slučaju da korisnik već ima validan token
    final isAllowed = RoleHelper.isSuperAdmin(user.roles) || RoleHelper.isAdmin(user.roles);
    if (!isAllowed) return _buildUnauthorizedMessage();

    if (RoleHelper.isSuperAdmin(user.roles)) {
      final pages = <Widget>[
        SuperAdminHomeScreen(user: user),
        SuperAdminAdminScreen(user: user),
      ];
      final safeIndex = index >= 0 && index < pages.length ? index : 0;
      return pages[safeIndex];
    }

    // Admin institucije desktop: samo administratorske funkcije (bez blagajnik/korisnik dijela)
    return InstitutionAdminAdminScreen(user: user);
  }

  List<NavigationRailDestination> _buildNavItems() {
    final user = globalAuthService.currentUser;
    if (user == null) return [];

    if (RoleHelper.isSuperAdmin(user.roles)) {
      return const [
        NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.admin_panel_settings), label: Text('Administrator')),
      ];
    }

    // Admin institucije (desktop): bez lijevog panela (zahtjev).
    // Direktno se prikazuje `InstitutionAdminAdminScreen`.
    if (RoleHelper.isAdmin(user.roles)) return const [];

    return const [];
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = globalAuthService.currentUser;
    final navItems = _buildNavItems();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Builder(
          builder: (context) {
            final w = MediaQuery.sizeOf(context).width;
            // Desktop: veći logo, ali i dalje ograničen da ne gura username/menu van ekrana
            final maxLogoWidth = (w * 0.55).clamp(320.0, 680.0);
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLogoWidth),
              child: SizedBox(
                height: 44,
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
      body: Row(
        children: [
          if (navItems.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onNavItemTapped,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.2, // spusti grupu malo niže (da ne bude "zalijepljena" za vrh)
                backgroundColor: Colors.transparent,
                destinations: navItems,
              ),
            ),
          if (navItems.isNotEmpty) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _getPageForIndex(_selectedIndex),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final user = globalAuthService.currentUser;
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(user: user),
                ),
              ).then((updated) {
                if (updated == true) {
                  // Refresh the screen to show updated data
                  setState(() {});
                }
              });
            },
            child: const Text('Uredi'),
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

  Widget _buildUnauthorizedMessage() {
    final user = globalAuthService.currentUser;
    final isBlagajnik = user != null && RoleHelper.isBlagajnik(user.roles);
    final isKorisnik = user != null && RoleHelper.isKorisnik(user.roles);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              isBlagajnik
                  ? 'Blagajnik korisnici ne mogu koristiti desktop aplikaciju'
                  : isKorisnik
                      ? 'Korisnici ne mogu koristiti desktop aplikaciju'
                      : 'Nemate pristup desktop aplikaciji',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isBlagajnik
                  ? 'Za skeniranje karata i blagajničke funkcije koristite mobilnu aplikaciju.'
                  : 'Molimo koristite mobilnu aplikaciju za pristup korisničkim funkcijama.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _handleLogout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Odjavi se'),
              // style preuzet iz shared ThemeHelper
            ),
          ],
        ),
      ),
    );
  }
}

