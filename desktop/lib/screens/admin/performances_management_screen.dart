import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/performance.dart';
import '../../models/institution.dart';
import '../../models/show.dart';
import '../../services/api_service.dart';
import '../../utils/theme_helper.dart';
import '../../main.dart';
import '../../utils/role_helper.dart';
import '../../widgets/color_coded_calendar_dialog.dart';

class PerformancesManagementScreen extends StatefulWidget {
  final int? institutionId;

  const PerformancesManagementScreen({super.key, this.institutionId});

  @override
  State<PerformancesManagementScreen> createState() => _PerformancesManagementScreenState();
}

class _PerformancesManagementScreenState extends State<PerformancesManagementScreen> {
  List<Performance> _performances = [];
  List<Show> _shows = [];
  List<Institution> _institutions = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedShowId;
  int? _selectedInstitutionId; // null => sve institucije (superadmin)
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = globalAuthService.currentUser;
    _isSuperAdmin = user != null && RoleHelper.isSuperAdmin(user.roles);
    // Ako je institucija već fiksirana (admin institucije), koristi je.
    _selectedInstitutionId = widget.institutionId;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final institutionsFuture =
          _isSuperAdmin ? ApiService.getInstitutions() : Future.value(<Institution>[]);
      final showsFuture = _fetchAllShowsForManagement(
        institutionId: _isSuperAdmin ? _selectedInstitutionId : widget.institutionId,
      );
      final performancesFuture = ApiService.getPerformances(
        showId: _selectedShowId,
        institutionId: _isSuperAdmin ? _selectedInstitutionId : widget.institutionId,
      );

      final results = await Future.wait([institutionsFuture, showsFuture, performancesFuture]);

      setState(() {
        _institutions = results[0] as List<Institution>;
        _shows = results[1] as List<Show>;
        _performances = results[2] as List<Performance>;
        _performances.sort((a, b) => a.startTime.compareTo(b.startTime));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Show>> _fetchAllShowsForManagement({int? institutionId}) async {
    const pageSize = 100; // backend max
    var page = 1;
    final all = <Show>[];
    var totalPages = 1;
    var totalCount = 0;

    while (true) {
      final resp = await ApiService.getShowsForManagement(
        pageNumber: page,
        pageSize: pageSize,
        institutionId: institutionId,
      );
      all.addAll(resp.shows);
      if (page == 1) {
        totalPages = resp.totalPages;
        totalCount = resp.totalCount;
      }

      if (resp.shows.isEmpty) break;
      if (page >= totalPages) break;
      if (all.length >= totalCount) break;
      page++;
    }

    final byId = <int, Show>{};
    for (final s in all) {
      byId[s.id] = s;
    }
    final result = byId.values.toList();
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  void _showCreateDialog() {
    _showPerformanceDialog();
  }

  void _showEditDialog(Performance performance) {
    _showPerformanceDialog(performance: performance);
  }

  Future<void> _selectDateTime(BuildContext context, Function(DateTime) onSelected, {int? showId}) async {
    final dialogContext = context;
    // Zauzetost dana: broj termina u tom danu (za instituciju predstave / filter institucije)
    int? institutionId;
    if (showId != null) {
      final matches = _shows.where((s) => s.id == showId).toList();
      if (matches.isNotEmpty) {
        institutionId = matches.first.institutionId;
      }
    } else if (_isSuperAdmin && _selectedInstitutionId != null) {
      institutionId = _selectedInstitutionId;
    } else if (!_isSuperAdmin && widget.institutionId != null) {
      institutionId = widget.institutionId;
    }

    List<Performance> listForCounts;
    if (institutionId != null) {
      try {
        listForCounts = await ApiService.getPerformances(
          institutionId: institutionId,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 365)),
        );
      } catch (_) {
        // fallback na trenutno učitane performanse
        listForCounts = _performances;
      }
    } else {
      listForCounts = _performances;
    }

    final dayCounts = <DateTime, int>{};
    for (final p in listForCounts) {
      final d = DateTime(p.startTime.year, p.startTime.month, p.startTime.day);
      dayCounts[d] = (dayCounts[d] ?? 0) + 1;
    }

    if (!dialogContext.mounted) return;
    final date = await ColorCodedCalendarDialog.pickDate(
      dialogContext,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      dayCounts: dayCounts,
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    onSelected(dateTime);
  }

  void _showPerformanceDialog({Performance? performance}) {
    int? selectedShowId = performance?.showId;
    DateTime? startTime = performance?.startTime;
    final priceController = TextEditingController(
      text: performance?.price.toStringAsFixed(2) ?? '',
    );
    String? validationError;

    double dialogWidth(BuildContext context) {
      final w = MediaQuery.of(context).size.width;
      return w >= 1100 ? 760 : (w * 0.92).clamp(360.0, 760.0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(performance == null ? 'Novi termin' : 'Uredi termin'),
          content: SizedBox(
            width: dialogWidth(context),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (validationError != null) ...[
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
                            validationError!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                DropdownButtonFormField<int>(
                  value: selectedShowId,
                  decoration: const InputDecoration(
                    labelText: 'Predstava *',
                    prefixIcon: Icon(Icons.theaters),
                    border: OutlineInputBorder(),
                    helperText: 'Obavezno polje. Kapacitet se automatski uzima iz institucije.',
                  ),
                  items: _shows.map((s) {
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.title),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedShowId = value;
                      if (validationError != null) {
                        validationError = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Datum i vrijeme *'),
                  subtitle: Text(
                    startTime != null
                        ? DateFormat('dd.MM.yyyy HH:mm').format(startTime!)
                        : 'Nije odabrano',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    await _selectDateTime(context, (dateTime) {
                      setDialogState(() {
                        startTime = dateTime;
                        if (validationError != null) {
                          validationError = null;
                        }
                      });
                    }, showId: selectedShowId);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Cijena (KM) *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    helperText: 'Obavezno polje. Cijena karte u KM. Mora biti veća ili jednaka 0.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() {
                        validationError = null;
                      });
                    }
                  },
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Odustani'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                // Validacija
                String? error;
                if (selectedShowId == null) {
                  error = 'Predstava je obavezna.';
                } else if (startTime == null) {
                  error = 'Datum i vrijeme su obavezni.';
                } else if (startTime!.isBefore(DateTime.now())) {
                  error = 'Datum i vrijeme moraju biti u budućnosti.';
                } else if (priceController.text.trim().isEmpty) {
                  error = 'Cijena je obavezna.';
                } else {
                  final price = double.tryParse(priceController.text.trim());
                  if (price == null) {
                    error = 'Cijena mora biti validan broj.';
                  } else if (price < 0) {
                    error = 'Cijena ne može biti negativna.';
                  }
                }

                if (error != null) {
                  setDialogState(() {
                    validationError = error;
                  });
                  return;
                }

                try {
                  final price = double.parse(priceController.text.trim());
                  final data = {
                    'showId': selectedShowId!,
                    // šaljemo UTC radi konzistentnosti (backend radi u UTC, UI prikazuje lokalno)
                    'startTime': startTime!.toUtc().toIso8601String(),
                    'price': price,
                  };

                  if (performance == null) {
                    await ApiService.createPerformance(data);
                  } else {
                    await ApiService.updatePerformance(performance.id, data);
                  }

                  if (!mounted) return;
                  
                  // Auto-clear forma nakon uspješnog save-a (samo ako je create)
                  if (performance == null) {
                    selectedShowId = null;
                    startTime = null;
                    priceController.clear();
                    validationError = null;
                  }
                  
                  // Auto-refresh liste
                  _loadData();
                  
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(performance == null ? 'Termin uspješno kreiran!' : 'Termin uspješno ažuriran!'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  final raw = e.toString();
                  final msg = raw.replaceFirst('Exception: ', '');
                  final errorMessage =
                      msg.contains('U tom terminu pozorište je već zauzeto.')
                          ? 'U tom terminu pozorište je već zauzeto.'
                          : (raw.contains('400') || raw.contains('Validation'))
                              ? 'Greška pri validaciji. Provjerite unesene podatke.'
                              : 'Greška: $msg';
                  
                  setDialogState(() {
                    validationError = errorMessage;
                  });
                }
              },
              icon: Icon(performance == null ? Icons.add : Icons.save),
              label: Text(performance == null ? 'Kreiraj' : 'Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Performance performance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje termina'),
        content: Text(
          'Da li ste sigurni da želite obrisati termin za "${performance.showTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.deletePerformance(performance.id);
                if (!mounted) return;
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Termin obrisan'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Greška: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
  }

  List<Performance> get _filteredPerformances {
    return _performances.where((p) {
      // Filter po Show-u
      final matchesShow = _selectedShowId == null || p.showId == _selectedShowId;

      // Desktop: filter po datumu je uklonjen (zahtjev).
      return matchesShow;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje terminima'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 1200;
                final filterWidth = isNarrow ? constraints.maxWidth : 360.0;

                Widget institutionFilter() => SizedBox(
                      width: filterWidth,
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
                            _selectedShowId = null;
                          });
                          _loadData();
                        },
                      ),
                    );

                Widget showFilter() => SizedBox(
                      width: filterWidth,
                      child: DropdownButtonFormField<int?>(
                        value: _selectedShowId,
                        decoration: const InputDecoration(
                          labelText: 'Predstava',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Sve predstave')),
                          ..._shows.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.title))),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedShowId = value);
                          _loadData();
                        },
                      ),
                    );

                final hasFilters = _selectedShowId != null || (_isSuperAdmin && _selectedInstitutionId != null);

                final children = <Widget>[
                  if (_isSuperAdmin) institutionFilter(),
                  showFilter(),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Novi termin'),
                  ),
                  if (hasFilters)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedShowId = null;
                          if (_isSuperAdmin) _selectedInstitutionId = null;
                        });
                        _loadData();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Očisti filtere'),
                    ),
                ];

                // Koristimo Wrap i na širokim ekranima da ne bi došlo do horizontalnog overflow-a
                // kada je prozor sužen ili kada su labele duže (npr. lokalizacija).
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: children,
                );
              },
            ),
          ),
          // Performances list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Greška: $_error', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Pokušaj ponovo'),
                            ),
                          ],
                        ),
                      )
                    : _filteredPerformances.isEmpty
                        ? const Center(
                            child: Text('Nema termina'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredPerformances.length,
                            itemBuilder: (context, index) {
                              final performance = _filteredPerformances[index];
                              // Provjeri da li je termin trenutno aktivan
                              final now = DateTime.now();
                              final showDuration = 90; // Default 90 minuta, možete dohvatiti iz Show modela ako je dostupan
                              final endTime = performance.startTime.add(Duration(minutes: showDuration));
                              final isCurrentlyShowing = performance.startTime.isBefore(now) && endTime.isAfter(now);
                              
                              // Određivanje boje na osnovu statusa koristeći ThemeHelper
                              final statusColor = ThemeHelper.getPerformanceStatusColor(
                                isSoldOut: performance.isSoldOut,
                                isAlmostSoldOut: performance.isAlmostSoldOut,
                                isCurrentlyShowing: isCurrentlyShowing,
                              );
                              final statusText = ThemeHelper.getPerformanceStatusText(
                                isSoldOut: performance.isSoldOut,
                                isAlmostSoldOut: performance.isAlmostSoldOut,
                                isCurrentlyShowing: isCurrentlyShowing,
                              );
                              final statusIcon = ThemeHelper.getPerformanceStatusIcon(
                                isSoldOut: performance.isSoldOut,
                                isAlmostSoldOut: performance.isAlmostSoldOut,
                                isCurrentlyShowing: isCurrentlyShowing,
                              );
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: statusColor, width: 2),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor,
                                    child: Icon(statusIcon, color: Colors.white),
                                  ),
                                  title: Text(
                                    performance.showTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${performance.formattedDate} u ${performance.formattedTime}'),
                                      Text('Cijena: ${performance.formattedPrice}'),
                                      Text('Dostupno mjesta: ${performance.availableSeats}'),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: statusColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showEditDialog(performance),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteDialog(performance),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

