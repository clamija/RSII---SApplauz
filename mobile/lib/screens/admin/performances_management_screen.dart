import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/performance.dart';
import '../../models/show.dart';
import '../../services/api_service.dart';
import '../../widgets/color_coded_calendar_dialog.dart';

class PerformancesManagementScreen extends StatefulWidget {
  const PerformancesManagementScreen({super.key});

  @override
  State<PerformancesManagementScreen> createState() => _PerformancesManagementScreenState();
}

class _PerformancesManagementScreenState extends State<PerformancesManagementScreen> {
  List<Performance> _allPerformances = [];
  List<Performance> _performances = []; // trenutno prikazana stranica
  List<Show> _shows = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedShowId;
  int _currentPage = 1;
  final int _pageSize = 20;

  String _err(Object e) => e
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .trim();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Backend limitira pageSize na max 100, pa moramo paginirati dok ne povučemo sve.
      final shows = await _fetchAllShowsForManagement();
      final performances = await _fetchAllPerformances(showId: _selectedShowId);

      setState(() {
        _shows = shows;
        _allPerformances = performances..sort((a, b) => a.startTime.compareTo(b.startTime));
        _currentPage = 1;
        _performances = _pageSlice();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Show>> _fetchAllShowsForManagement() async {
    const pageSize = 100; // max na backendu
    var page = 1;
    final all = <Show>[];
    var totalPages = 1;
    var totalCount = 0;

    while (true) {
      final resp = await ApiService.getShowsForManagement(pageNumber: page, pageSize: pageSize);
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

    // Dedup po ID (sigurnosno, ako backend ikad vrati duplikate)
    final byId = <int, Show>{};
    for (final s in all) {
      byId[s.id] = s;
    }
    final result = byId.values.toList();
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  Future<void> _loadPerformances() async {
    try {
      final performances = await _fetchAllPerformances(showId: _selectedShowId);
      setState(() {
        _allPerformances = performances..sort((a, b) => a.startTime.compareTo(b.startTime));
        _currentPage = 1;
        _performances = _pageSlice();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  int get _totalPages {
    if (_allPerformances.isEmpty) return 1;
    return ((_allPerformances.length + _pageSize - 1) / _pageSize).floor();
  }

  List<Performance> _pageSlice() {
    if (_allPerformances.isEmpty) return [];
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _allPerformances.length) return [];
    final end = (start + _pageSize).clamp(0, _allPerformances.length);
    return _allPerformances.sublist(start, end);
  }

  Future<List<Performance>> _fetchAllPerformances({int? showId}) async {
    const apiPageSize = 100; // backend max
    var page = 1;
    final all = <Performance>[];

    while (true) {
      final chunk = await ApiService.getPerformances(
        pageNumber: page,
        pageSize: apiPageSize,
        showId: showId,
      );
      all.addAll(chunk);
      if (chunk.length < apiPageSize) break;
      page++;
    }

    // Dedup po ID (sigurnosno)
    final byId = <int, Performance>{};
    for (final p in all) {
      byId[p.id] = p;
    }
    return byId.values.toList();
  }

  Future<void> _deletePerformance(Performance performance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje termina'),
        content: Text('Da li ste sigurni da želite obrisati termin za "${performance.showTitle}"?'),
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
        await ApiService.deletePerformance(performance.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Termin je uspješno obrisan')),
          );
          _loadPerformances();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_err(e))),
          );
        }
      }
    }
  }

  void _showAddEditDialog({Performance? performance, Show? preselectedShow}) {
    final formKey = GlobalKey<FormState>();
    int? selectedShowId = performance?.showId ?? preselectedShow?.id ?? _selectedShowId;
    DateTime selectedDate = performance?.startTime ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(performance?.startTime ?? DateTime.now());
    final priceController = TextEditingController(
      text: performance?.price.toStringAsFixed(2) ?? '0.00',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(performance == null ? 'Dodaj termin' : 'Uredi termin'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedShowId,
                    decoration: const InputDecoration(
                      labelText: 'Predstava *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
                    items: _shows.map((show) {
                      return DropdownMenuItem(
                        value: show.id,
                        child: Text(show.title, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedShowId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Molimo odaberite predstavu' : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Datum'),
                    subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final dialogContext = context;
                      // Zauzetost dana: broj termina u tom danu (za instituciju predstave)
                      final dialogShowId = selectedShowId;
                      int? institutionId;
                      if (dialogShowId != null) {
                        final matches = _shows.where((s) => s.id == dialogShowId).toList();
                        if (matches.isNotEmpty) {
                          institutionId = matches.first.institutionId;
                        }
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
                      final picked = await ColorCodedCalendarDialog.pickDate(
                        dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        dayCounts: dayCounts,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Vrijeme'),
                    subtitle: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Cijena (KM) *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Molimo unesite cijenu';
                      if (double.tryParse(value!) == null) return 'Molimo unesite validan broj';
                      if (double.parse(value) < 0) return 'Cijena mora biti veća ili jednaka 0';
                      return null;
                    },
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
                  if (selectedShowId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Molimo odaberite predstavu')),
                    );
                    return;
                  }

                  try {
                    final dateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final data = {
                      'showId': selectedShowId,
                      // šaljemo UTC radi konzistentnosti (backend radi u UTC, UI prikazuje lokalno)
                      'startTime': dateTime.toUtc().toIso8601String(),
                      'price': double.parse(priceController.text.trim()),
                    };

                    if (performance == null) {
                      await ApiService.createPerformance(data);
                    } else {
                      await ApiService.updatePerformance(performance.id, data);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            performance == null 
                                ? 'Termin je uspješno dodan' 
                                : 'Termin je uspješno ažuriran',
                          ),
                        ),
                      );
                      _loadPerformances();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _err(e),
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(performance == null ? 'Dodaj' : 'Sačuvaj'),
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
        title: const Text('Upravljanje Terminima'),
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
                        onPressed: _loadData,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<int>(
                        value: _selectedShowId,
                        decoration: const InputDecoration(
                          labelText: 'Filtriraj po predstavi',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.filter_list),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Sve predstave'),
                          ),
                          ..._shows.map((show) {
                            return DropdownMenuItem(
                              value: show.id,
                              child: Text(show.title, overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedShowId = value;
                          });
                          _loadPerformances();
                        },
                      ),
                    ),
                    Expanded(
                      child: _performances.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nema termina${_selectedShowId == null ? '' : ' za odabranu predstavu'}',
                                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPerformances,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _performances.length,
                                      itemBuilder: (context, index) {
                                        final performance = _performances[index];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: performance.isSoldOut
                                                  ? Colors.red
                                                  : performance.isAlmostSoldOut
                                                      ? Colors.orange
                                                      : Colors.green,
                                              child: Text(
                                                '${performance.availableSeats}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              performance.showTitle,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('${performance.formattedDate} u ${performance.formattedTime}'),
                                                Text(
                                                  'Cijena: ${performance.formattedPrice}',
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                ),
                                                Text(
                                                  'Dostupna mjesta: ${performance.availableSeats}',
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                                                  _showAddEditDialog(performance: performance);
                                                } else if (value == 'delete') {
                                                  _deletePerformance(performance);
                                                }
                                              },
                                            ),
                                            isThreeLine: true,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_totalPages > 1)
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
                                                      _performances = _pageSlice();
                                                    });
                                                  }
                                                : null,
                                          ),
                                          Text('Stranica $_currentPage od $_totalPages'),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right),
                                            onPressed: _currentPage < _totalPages
                                                ? () {
                                                    setState(() {
                                                      _currentPage++;
                                                      _performances = _pageSlice();
                                                    });
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(
          preselectedShow: _selectedShowId != null
              ? _shows.firstWhere((s) => s.id == _selectedShowId)
              : null,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
