import 'package:flutter/material.dart';

import '../../models/create_user_request.dart';
import '../../models/update_user_request.dart';
import '../../models/update_user_roles_request.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../utils/role_helper.dart';
import '../../main.dart';

Future<bool?> showUserFormDialog(
  BuildContext context, {
  User? user,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UserFormDialog(user: user),
  );
}

class _UserFormDialog extends StatefulWidget {
  final User? user;
  const _UserFormDialog({this.user});

  bool get isEdit => user != null;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<String> _availableRoles = [];
  String? _selectedRole;
  bool _isLoading = false;
  bool _isLoadingRoles = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user?.lastName ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _selectedRole = (widget.user?.roles.isNotEmpty ?? false) ? widget.user!.roles.first : null;
    _loadAvailableRoles();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _dialogWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 1100 ? 760 : (w * 0.92).clamp(360.0, 760.0);
  }

  Future<void> _loadAvailableRoles() async {
    try {
      var roles = await ApiService.getAvailableRoles();

      // Ukloni duplikate i generičke uloge (Admin/Blagajnik) – moraju biti vezane za konkretnu instituciju.
      roles = roles.toSet().toList();
      roles = roles.where((r) {
        final role = r.trim().toLowerCase();
        return role != RoleHelper.admin.toLowerCase() && role != RoleHelper.blagajnik.toLowerCase();
      }).toList();

      // Admin institucije: može dodavati role samo za svoju instituciju (+ Korisnik).
      final currentUser = globalAuthService.currentUser;
      if (currentUser != null &&
          RoleHelper.isAdmin(currentUser.roles) &&
          !RoleHelper.isSuperAdmin(currentUser.roles)) {
        final institutionId =
            currentUser.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(currentUser.roles);
        final code = RoleHelper.tryGetInstitutionCodeFromId(institutionId);
        if (code != null) {
          roles = roles.where((r) {
            final lower = r.trim().toLowerCase();
            if (lower == RoleHelper.korisnik.toLowerCase()) return true;
            final rCode = RoleHelper.tryGetInstitutionCodeFromRoleName(r);
            return rCode != null && rCode == code;
          }).toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _availableRoles = roles;
        _isLoadingRoles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoles = false;
        _validationError = 'Greška pri učitavanju uloga: $e';
      });
    }
  }

  String _roleLabel(String role) {
    return RoleHelper.getRoleDisplayName(role);
  }

  Future<void> _submit() async {
    setState(() => _validationError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null || _selectedRole!.trim().isEmpty) {
      setState(() => _validationError = 'Odaberite ulogu.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (!widget.isEdit) {
        final request = CreateUserRequest(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          roles: [_selectedRole!],
        );
        await ApiService.createUser(request.toJson());
      } else {
        final u = widget.user!;
        final updateRequest = UpdateUserRequest(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
        );
        await ApiService.updateUser(u.id, updateRequest.toJson());

        final rolesRequest = UpdateUserRolesRequest(roles: [_selectedRole!]);
        await ApiService.updateUserRoles(u.id, rolesRequest.toJson());
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _validationError = 'Greška: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Uredi korisnika' : 'Novi korisnik';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: _dialogWidth(context),
        child: _isLoadingRoles
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_validationError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'Ime *', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Ime je obavezno' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Prezime *', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Prezime je obavezno' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Email je obavezan';
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value.trim())) return 'Molimo unesite validan email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!widget.isEdit) ...[
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Lozinka *', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lozinka je obavezna';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(labelText: 'Potvrdi lozinku *', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Potvrda lozinke je obavezna';
                            if (value != _passwordController.text) return 'Lozinke se ne poklapaju';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(labelText: 'Uloga *', border: OutlineInputBorder()),
                        items: _availableRoles
                            .map((r) => DropdownMenuItem<String>(value: r, child: Text(_roleLabel(r))))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedRole = value),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: Text(widget.isEdit ? 'Sačuvaj' : 'Kreiraj'),
        ),
      ],
    );
  }
}

