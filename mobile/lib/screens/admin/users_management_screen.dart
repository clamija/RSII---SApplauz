import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/user_list_response.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/role_helper.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  UserListResponse? _userListResponse;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({int page = 1, String? search}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = page;
    });

    try {
      final response = await ApiService.getUsers(
        page: page,
        pageSize: _pageSize,
        search: search,
      );
      setState(() {
        _userListResponse = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje korisnika'),
        content: Text('Da li ste sigurni da želite obrisati korisnika "${user.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteUser(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Korisnik je uspješno obrisan')),
          );
          _loadUsers(page: _currentPage, search: _searchController.text.isEmpty ? null : _searchController.text);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška pri brisanju: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showAddEditDialog({User? user}) async {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: user?.firstName ?? '');
    final lastNameController = TextEditingController(text: user?.lastName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final currentUser = AuthService.instance.currentUser;
    final isSuperAdmin = currentUser != null && RoleHelper.isSuperAdmin(currentUser.roles);
    
    List<String> availableRoles = [];
    String? selectedRole;
    if (user != null && user.roles.isNotEmpty) {
      // Preferiraj institucijske role (adminXXX / blagajnikXXX) ako postoje
      String? pickInstitutionSpecific(String prefix) {
        return user.roles
            .map((r) => r.trim())
            .firstWhere(
              (r) => r.toLowerCase().startsWith(prefix) && r.length > prefix.length,
              orElse: () => '',
            )
            .trim()
            .isEmpty
            ? null
            : user.roles
                .map((r) => r.trim())
                .firstWhere(
                  (r) => r.toLowerCase().startsWith(prefix) && r.length > prefix.length,
                );
      }

      selectedRole = pickInstitutionSpecific('admin') ?? pickInstitutionSpecific('blagajnik');

      // Ako korisnik ima generičku rolu ("Admin"/"Blagajnik"), mapiraj je na institucijsku (adminXXX/blagajnikXXX)
      // na osnovu InstitutionId (da se u UI i u request-u koristi isključivo institucijska rola).
      if (selectedRole == null) {
        final hasGenericAdmin = user.roles.any((r) => r.trim().toLowerCase() == RoleHelper.admin.toLowerCase());
        final hasGenericBlagajnik = user.roles.any((r) => r.trim().toLowerCase() == RoleHelper.blagajnik.toLowerCase());
        final code = RoleHelper.tryGetInstitutionCodeFromId(user.institutionId);
        if (code != null) {
          if (hasGenericAdmin) selectedRole = 'admin$code';
          if (hasGenericBlagajnik) selectedRole = 'blagajnik$code';
        }
      }

      selectedRole ??= user.roles.first;
    }

    try {
      availableRoles = await ApiService.getAvailableRoles();
      // Ukloni duplikate i osiguraj da ima jedinstvene vrijednosti
      availableRoles = availableRoles.toSet().toList();
      // Ukloni generičke uloge "Admin" i "Blagajnik" (koristimo samo adminXXX/blagajnikXXX)
      availableRoles = availableRoles.where((r) {
        final role = r.trim().toLowerCase();
        return role != RoleHelper.admin.toLowerCase() && role != RoleHelper.blagajnik.toLowerCase();
      }).toList();

      // Ako uređujemo postojećeg korisnika i njegova trenutna uloga nije u listi (npr. stara generička "Blagajnik"),
      // dodaj je da DropdownButton ne pukne (mora imati tačno jedan item sa value==selectedRole).
      if (selectedRole != null) {
        final selLower = selectedRole.trim().toLowerCase();
        final hasSelected = availableRoles.any((r) => r.trim().toLowerCase() == selLower);
        if (!hasSelected) {
          // Ne dodaj generičke admin/blagajnik opcije nazad u listu; dodaj samo ako je stvarno institucijska rola.
          if (!(selLower == RoleHelper.admin.toLowerCase() || selLower == RoleHelper.blagajnik.toLowerCase())) {
            availableRoles.add(selectedRole.trim());
          }
        }
      }
    } catch (e) {
      // Fallback bez generičkih Admin/Blagajnik (samo osnovne)
      availableRoles = [RoleHelper.superAdmin, RoleHelper.korisnik];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Dodaj korisnika' : 'Uredi korisnika'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Ime *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Molimo unesite ime' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Prezime *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Molimo unesite prezime' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: user == null || isSuperAdmin, // SuperAdmin može mijenjati email
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Molimo unesite email';
                      if (!value!.contains('@')) return 'Molimo unesite validan email';
                      return null;
                    },
                  ),
                  if (user == null) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Lozinka *',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Molimo unesite lozinku';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Potvrdi lozinku *',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Molimo potvrdite lozinku';
                        if (value != passwordController.text) return 'Lozinke se ne podudaraju';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Uloga *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: availableRoles.toSet().toList().map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            RoleHelper.getRoleDisplayName(role),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRole = value;
                      });
                    },
                    validator: (value) => value == null ? 'Molimo odaberite ulogu' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Otkaži'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  if (user == null && passwordController.text != confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lozinke se ne podudaraju')),
                    );
                    return;
                  }

                  if (selectedRole == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Molimo odaberite ulogu')),
                    );
                    return;
                  }

                  try {
                    if (user == null) {
                      final data = {
                        'firstName': firstNameController.text.trim(),
                        'lastName': lastNameController.text.trim(),
                        'email': emailController.text.trim(),
                        'password': passwordController.text,
                        'roles': [selectedRole!],
                      };
                      await ApiService.createUser(data);
                    } else {
                      final data = {
                        'firstName': firstNameController.text.trim(),
                        'lastName': lastNameController.text.trim(),
                        // Backend zahtijeva Email u UpdateUserRequest (inače postane prazan string i update padne)
                        'email': emailController.text.trim(),
                      };
                      await ApiService.updateUser(user.id, data);
                      
                      // Ažuriraj uloge odvojeno
                      final currentRole = user.roles.isNotEmpty ? user.roles.first : null;
                      if (selectedRole != currentRole) {
                        await ApiService.updateUserRoles(user.id, {'roles': [selectedRole!]});
                      }
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            user == null 
                                ? 'Korisnik je uspješno dodan' 
                                : 'Korisnik je uspješno ažuriran',
                          ),
                        ),
                      );
                      _loadUsers(page: _currentPage, search: _searchController.text.isEmpty ? null : _searchController.text);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Greška: ${e.toString()}')),
                      );
                    }
                  }
                }
              },
              child: Text(user == null ? 'Dodaj' : 'Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje Korisnicima'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pretraži korisnike...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadUsers();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                _loadUsers(page: 1, search: value.isEmpty ? null : value);
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Greška: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadUsers(page: _currentPage),
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : _userListResponse == null || _userListResponse!.users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nema korisnika',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          // Button je uklonjen jer već postoji FAB "Dodaj" na dnu ekrana
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadUsers(page: _currentPage, search: _searchController.text.isEmpty ? null : _searchController.text),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _userListResponse!.users.length,
                              itemBuilder: (context, index) {
                                final user = _userListResponse!.users[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        user.firstName[0].toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      user.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user.email),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          children: user.roles.map((role) => Chip(
                                            label: Text(
                                              RoleHelper.getRoleDisplayName(role),
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            padding: EdgeInsets.zero,
                                          )).toList(),
                                        ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton(
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Uredi'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Obriši', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showAddEditDialog(user: user);
                                        } else if (value == 'delete') {
                                          _deleteUser(user);
                                        }
                                      },
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_userListResponse!.totalPages > 1)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 1
                                        ? () => _loadUsers(page: _currentPage - 1, search: _searchController.text.isEmpty ? null : _searchController.text)
                                        : null,
                                  ),
                                  Text('Stranica $_currentPage od ${_userListResponse!.totalPages}'),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _currentPage < _userListResponse!.totalPages
                                        ? () => _loadUsers(page: _currentPage + 1, search: _searchController.text.isEmpty ? null : _searchController.text)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
