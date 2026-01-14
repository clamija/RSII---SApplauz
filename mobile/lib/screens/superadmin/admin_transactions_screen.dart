import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../../models/order_list_response.dart';
import '../../models/institution.dart';
import '../../services/api_service.dart';
import '../../utils/role_helper.dart';

class AdminTransactionsScreen extends StatefulWidget {
  final User user;
  final bool isSuperAdmin;

  const AdminTransactionsScreen({
    super.key,
    required this.user,
    this.isSuperAdmin = false,
  });

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  OrderListResponse? _orderListResponse;
  List<Institution> _institutions = [];
  int? _selectedInstitutionId;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  List<Order> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    if (widget.isSuperAdmin) {
      _loadInstitutions();
    } else {
      _selectedInstitutionId =
          widget.user.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(widget.user.roles);
    }
    _loadOrders();
  }

  Future<void> _loadInstitutions() async {
    try {
      final institutions = await ApiService.getInstitutions();
      setState(() {
        _institutions = institutions;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadOrders() async {
    // Za Admin institucije, backend svakako ograničava po tokenu; nemoj blokirati load ako institutionId nije stigao u DTO-u.

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Za SuperAdmin, ako je null, ne šalji institutionId (vrati sve)
      final response = await ApiService.getInstitutionOrders(
        institutionId: widget.isSuperAdmin 
            ? _selectedInstitutionId
            : _selectedInstitutionId,
        pageNumber: _currentPage,
        pageSize: _pageSize,
        status: _selectedStatus,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _orderListResponse = response;
        _filteredOrders = _applyOrderFilters(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Order> _applyOrderFilters(OrderListResponse response) {
    return response.orders.where((order) {
      final matchesStatus = _selectedStatus == null ||
          order.status.toLowerCase() == _selectedStatus!.toLowerCase();
      final matchesInstitution = _selectedInstitutionId == null ||
          (order.institutionId != null && order.institutionId == _selectedInstitutionId);
      return matchesStatus && matchesInstitution;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      case 'refunded':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isSuperAdmin ? 'Transakcije (Sve Institucije)' : 'Transakcije Institucije'),
            if (widget.isSuperAdmin && _selectedInstitutionId != null)
              Text(
                _institutions.firstWhere((i) => i.id == _selectedInstitutionId).name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filteri
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (widget.isSuperAdmin && _institutions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: DropdownButtonFormField<int>(
                      value: _selectedInstitutionId,
                      decoration: const InputDecoration(
                        labelText: 'Institucija',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sve institucije'),
                        ),
                        ..._institutions.map((institution) {
                          return DropdownMenuItem(
                            value: institution.id,
                            child: Text(institution.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedInstitutionId = value;
                          _currentPage = 1;
                        });
                        _loadOrders();
                      },
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Svi statusi')),
                          const DropdownMenuItem(value: 'paid', child: Text('Plaćeno')),
                          const DropdownMenuItem(value: 'pending', child: Text('Na čekanju')),
                          const DropdownMenuItem(value: 'refunded', child: Text('Refundirano')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                            _currentPage = 1;
                          });
                          _loadOrders();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedStatus = null;
                          _startDate = null;
                          _endDate = null;
                          _currentPage = 1;
                        });
                        _loadOrders();
                      },
                      tooltip: 'Obriši filtere',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Greška: $_errorMessage'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadOrders,
                              child: const Text('Pokušaj ponovo'),
                            ),
                          ],
                        ),
                      )
                    : _orderListResponse == null || _filteredOrders.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Nema narudžbi',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredOrders.length,
                                    itemBuilder: (context, index) {
                                      final order = _filteredOrders[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: ExpansionTile(
                                          leading: CircleAvatar(
                                            backgroundColor: _getStatusColor(order.status),
                                            child: Text(
                                              order.id.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            'Narudžba #${order.id}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Kupac: ${order.userName}'),
                                              Text(
                                                'Datum: ${DateFormat('dd.MM.yyyy HH:mm').format(((order.status.toLowerCase() == 'refunded' && order.updatedAt != null) ? order.updatedAt! : order.createdAt).toLocal())}',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                              Text(
                                                'Ukupno: ${order.formattedTotalAmount}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Chip(
                                            label: Text(
                                              order.statusDisplayName,
                                              style: const TextStyle(color: Colors.white, fontSize: 10),
                                            ),
                                            backgroundColor: _getStatusColor(order.status),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Divider(),
                                                  Text(
                                                    'Institucija: ${order.institutionName}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Karte:',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  ...order.orderItems.map((item) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(left: 16, top: 4),
                                                      child: Text(
                                                        '${item.quantity}x ${item.performanceShowTitle} - ${DateFormat('dd.MM.yyyy HH:mm').format(item.performanceStartTime.toLocal())}',
                                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_orderListResponse!.totalPages > 1)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed: _currentPage > 1
                                              ? () {
                                                  setState(() {
                                                    _currentPage--;
                                                  });
                                                  _loadOrders();
                                                }
                                              : null,
                                        ),
                                        Text('Stranica $_currentPage od ${_orderListResponse!.totalPages}'),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed: _currentPage < _orderListResponse!.totalPages
                                              ? () {
                                                  setState(() {
                                                    _currentPage++;
                                                  });
                                                  _loadOrders();
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
