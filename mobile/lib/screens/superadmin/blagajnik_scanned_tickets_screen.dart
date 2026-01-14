import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/ticket.dart';
import '../../models/institution.dart';
import '../../services/api_service.dart';
import '../../utils/role_helper.dart';

class BlagajnikScannedTicketsScreen extends StatefulWidget {
  final User user;
  final bool isSuperAdmin;

  const BlagajnikScannedTicketsScreen({
    super.key,
    required this.user,
    this.isSuperAdmin = false,
  });

  @override
  State<BlagajnikScannedTicketsScreen> createState() => _BlagajnikScannedTicketsScreenState();
}

class _BlagajnikScannedTicketsScreenState extends State<BlagajnikScannedTicketsScreen> {
  List<Ticket> _tickets = [];
  List<Institution> _institutions = [];
  int? _selectedInstitutionId;
  String? _selectedStatus;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isSuperAdmin) {
      _loadInstitutions();
    } else {
      _selectedInstitutionId =
          widget.user.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(widget.user.roles);
      _loadTickets();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInstitutions() async {
    try {
      final institutions = await ApiService.getInstitutions();
      setState(() {
        _institutions = institutions;
        // SuperAdmin: default na "Sve institucije"
        _selectedInstitutionId = null;
      });
      _loadTickets();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Koristi getScannedTickets za SuperAdmin ili Blagajnik
      // Za SuperAdmin, ako je null, ne šalji institutionId (vrati sve)
      final tickets = await ApiService.getScannedTickets(
        institutionId: widget.isSuperAdmin 
            ? _selectedInstitutionId
            : _selectedInstitutionId,
        status: _selectedStatus,
      );

      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scanned':
        return Colors.green;
      case 'invalid':
        return Colors.red;
      case 'notscanned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scanned':
        return Icons.check_circle;
      case 'invalid':
        return Icons.cancel;
      case 'notscanned':
        return Icons.pending;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pregled karata'),
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
                    child: DropdownButtonFormField<int?>(
                      value: _selectedInstitutionId,
                      decoration: const InputDecoration(
                        labelText: 'Institucija',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sve institucije'),
                        ),
                        ..._institutions.map((institution) {
                          return DropdownMenuItem<int?>(
                            value: institution.id,
                            child: Text(institution.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedInstitutionId = value;
                        });
                        _loadTickets();
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
                          if (widget.isSuperAdmin)
                            const DropdownMenuItem(value: 'notscanned', child: Text('Važeća (Nije skenirana)')),
                          const DropdownMenuItem(value: 'scanned', child: Text('Skenirana')),
                          const DropdownMenuItem(value: 'invalid', child: Text('Nevažeća')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                          _loadTickets();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedStatus = null;
                        });
                        _loadTickets();
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
                              onPressed: _loadTickets,
                              child: const Text('Pokušaj ponovo'),
                            ),
                          ],
                        ),
                      )
                    : _tickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  widget.isSuperAdmin
                                      ? 'Nema karata za prikaz'
                                      : 'Nema skeniranih karata',
                                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadTickets,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _tickets.length,
                              itemBuilder: (context, index) {
                                final ticket = _tickets[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(ticket.status),
                                      child: Icon(
                                        _getStatusIcon(ticket.status),
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      ticket.showTitle,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Institucija: ${ticket.institutionName}'),
                                        Text(
                                          'Datum: ${ticket.formattedDate} u ${ticket.formattedTime}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                        if (ticket.scannedAt != null)
                                          Text(
                                            'Skenirano: ${DateFormat('dd.MM.yyyy HH:mm').format(ticket.scannedAt!.toLocal())}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                      ],
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        ticket.statusDisplayName,
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                      backgroundColor: _getStatusColor(ticket.status),
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
