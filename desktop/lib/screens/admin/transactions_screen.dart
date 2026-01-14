import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models/institution.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/role_helper.dart';

class TransactionsScreen extends StatefulWidget {
  final int? initialInstitutionId;

  const TransactionsScreen({super.key, this.initialInstitutionId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _km = NumberFormat.currency(locale: 'bs_BA', symbol: 'KM');

  bool _isSuperAdmin = false;
  int? _selectedInstitutionId;
  String? _selectedStatus;

  List<Institution> _institutions = [];
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

  int _pageNumber = 1;
  final int _pageSize = 25;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    final user = globalAuthService.currentUser;
    _isSuperAdmin = user != null && RoleHelper.isSuperAdmin(user.roles);

    // Admin institucije: implicitni filter po instituciji (1:1 kao mobile)
    if (!_isSuperAdmin) {
      _selectedInstitutionId =
          user?.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(user?.roles ?? const []);
    } else {
      _selectedInstitutionId = widget.initialInstitutionId;
    }

    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (_isSuperAdmin) {
        // superadmin može birati instituciju
        _institutions = await ApiService.getInstitutions();
      } else {
        _institutions = const [];
      }

      final result = await ApiService.getInstitutionOrders(
        institutionId: _selectedInstitutionId,
        pageNumber: _pageNumber,
        pageSize: _pageSize,
        status: _selectedStatus,
      );

      setState(() {
        _orders = result.orders;
        _totalPages = result.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transakcije'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Greška: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildFilters(),
                    const Divider(height: 1),
                    Expanded(child: _buildTable()),
                    _buildPagination(),
                  ],
                ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;

          Widget institutionFilter() => SizedBox(
                width: isNarrow ? constraints.maxWidth : 320,
                child: DropdownButtonFormField<int?>(
                  value: _selectedInstitutionId,
                  decoration: const InputDecoration(
                    labelText: 'Institucija',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Sve institucije')),
                    ..._institutions.map((i) => DropdownMenuItem<int?>(value: i.id, child: Text(i.name))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedInstitutionId = value;
                      _pageNumber = 1;
                    });
                    _load();
                  },
                ),
              );

          Widget statusFilter() => SizedBox(
                width: isNarrow ? constraints.maxWidth : 320,
                child: DropdownButtonFormField<String?>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('Svi statusi')),
                    DropdownMenuItem<String?>(value: 'Pending', child: Text('Na čekanju')),
                    DropdownMenuItem<String?>(value: 'Paid', child: Text('Plaćeno')),
                    DropdownMenuItem<String?>(value: 'Refunded', child: Text('Refundirano')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                      _pageNumber = 1;
                    });
                    _load();
                  },
                ),
              );

          final hasFilters = _selectedStatus != null || (_isSuperAdmin && _selectedInstitutionId != null);

          if (isNarrow) {
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                if (_isSuperAdmin) institutionFilter(),
                statusFilter(),
                if (hasFilters)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _pageNumber = 1;
                        if (_isSuperAdmin) _selectedInstitutionId = null;
                      });
                      _load();
                    },
                    child: const Text('Reset'),
                  ),
              ],
            );
          }

          return Row(
            children: [
              if (_isSuperAdmin) institutionFilter(),
              if (_isSuperAdmin) const SizedBox(width: 12),
              statusFilter(),
              const Spacer(),
              if (hasFilters)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = null;
                      _pageNumber = 1;
                      if (_isSuperAdmin) _selectedInstitutionId = null;
                    });
                    _load();
                  },
                  child: const Text('Reset'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTable() {
    if (_orders.isEmpty) {
      return const Center(child: Text('Nema transakcija za odabrane filtere.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: DataTable(
        columns: [
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('Korisnik')),
          if (_isSuperAdmin) const DataColumn(label: Text('Institucija')),
          const DataColumn(label: Text('Datum')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Iznos')),
          const DataColumn(label: Text('Stavke')),
        ],
        rows: _orders.map((o) {
          final date = DateFormat('dd.MM.yyyy HH:mm').format(((o.status.toLowerCase() == 'refunded' && o.updatedAt != null) ? o.updatedAt! : o.createdAt).toLocal());
          return DataRow(
            cells: [
              DataCell(Text('#${o.id}')),
              DataCell(Text(o.userName)),
              if (_isSuperAdmin) DataCell(Text(o.institutionName)),
              DataCell(Text(date)),
              DataCell(Text(o.statusDisplayName)),
              DataCell(Text(_km.format(o.totalAmount))),
              DataCell(Text(o.orderItems.length.toString())),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Stranica $_pageNumber / $_totalPages'),
          const Spacer(),
          IconButton(
            onPressed: _pageNumber > 1
                ? () {
                    setState(() => _pageNumber--);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: _pageNumber < _totalPages
                ? () {
                    setState(() => _pageNumber++);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

