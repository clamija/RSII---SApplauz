import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/institution.dart';
import '../../models/popularity_report.dart';
import '../../services/api_service.dart';
import '../../utils/role_helper.dart';

class ManagerReportsScreen extends StatefulWidget {
  final int? fixedInstitutionId; // admin institucije: bez dropdown-a

  const ManagerReportsScreen({super.key, this.fixedInstitutionId});

  @override
  State<ManagerReportsScreen> createState() => _ManagerReportsScreenState();
}

class _ManagerReportsScreenState extends State<ManagerReportsScreen> {
  final _searchController = TextEditingController();

  List<Institution> _institutions = [];
  int? _selectedInstitutionId;
  bool _loadingInstitutions = true;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  PopularityReport? _report;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutions() async {
    try {
      setState(() {
        _loadingInstitutions = true;
        _error = null;
      });
      final list = await ApiService.getInstitutions();
      setState(() {
        _institutions = list;
        if (widget.fixedInstitutionId != null) {
          _selectedInstitutionId = widget.fixedInstitutionId;
        } else {
          _selectedInstitutionId ??= list.isNotEmpty ? list.first.id : null;
        }
        _loadingInstitutions = false;
      });
      if (_selectedInstitutionId != null) {
        await _loadReport();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingInstitutions = false;
      });
    }
  }

  DateTime _monthStart(DateTime month) => DateTime(month.year, month.month, 1);
  DateTime _monthEnd(DateTime month) => DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  static const List<String> _bsMonths = [
    'januar',
    'februar',
    'mart',
    'april',
    'maj',
    'juni',
    'juli',
    'august',
    'septembar',
    'oktobar',
    'novembar',
    'decembar',
  ];

  String _monthLabel(DateTime month) {
    final m = _bsMonths[(month.month - 1).clamp(0, 11)];
    return '$m ${month.year}';
  }

  String _reportTitle(DateTime month, String institutionName) {
    final m = _monthLabel(month);
    return 'Ukupno prodano ulaznica u $m - $institutionName';
  }

  String _reportFileBaseName(DateTime month, Institution institution) {
    final code = RoleHelper.tryGetInstitutionCodeFromId(institution.id) ?? _sanitizeFileName(institution.name);
    final m = _monthLabel(month);
    // Windows ne dozvoljava filename koji završava tačkom; zato bez završne tačke u filename.
    return 'SApplauz - menadžerski izvještaj $code - $m';
  }

  String _asciiBosnian(String input) {
    return input
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('đ', 'dj')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('Č', 'C')
        .replaceAll('Ć', 'C')
        .replaceAll('Đ', 'Dj')
        .replaceAll('Š', 'S')
        .replaceAll('Ž', 'Z');
  }

  List<DateTime> get _monthsList {
    final now = DateTime.now();
    final start = DateTime(now.year - 2, now.month, 1); // last ~24 months
    final months = <DateTime>[];
    var cursor = DateTime(now.year, now.month, 1);
    while (cursor.isAfter(start) || cursor.isAtSameMomentAs(start)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1, 1);
    }
    return months;
  }

  List<DateTime> get _filteredMonths {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _monthsList;
    return _monthsList.where((m) => _monthLabel(m).toLowerCase().contains(q)).toList();
  }

  Institution? get _selectedInstitution =>
      _institutions.where((i) => i.id == _selectedInstitutionId).cast<Institution?>().firstWhere((e) => true, orElse: () => null);

  Future<void> _loadReport() async {
    if (_selectedInstitutionId == null) return;
    setState(() {
      _loadingReport = true;
      _error = null;
    });
    try {
      final report = await ApiService.getPopularityReport(
        startDate: _monthStart(_selectedMonth),
        endDate: _monthEnd(_selectedMonth),
        institutionId: _selectedInstitutionId,
      );
      setState(() {
        _report = report;
        _loadingReport = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingReport = false;
      });
    }
  }

  String _sanitizeFileName(String input) {
    final replaced = input.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return replaced.isEmpty ? 'izvjestaj' : replaced;
  }

  String _defaultDownloadsDir() {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null) return Directory.current.path;
    final sep = Platform.pathSeparator;
    final downloads = home.endsWith(sep) ? '${home}Downloads' : '$home${sep}Downloads';
    return downloads;
  }

  Future<void> _downloadPdfForMonth(DateTime month) async {
    final institution = _selectedInstitution;
    if (institution == null || _selectedInstitutionId == null) return;

    setState(() => _loadingReport = true);
    try {
      // Always fetch fresh for the specific month being downloaded
      final report = await ApiService.getPopularityReport(
        startDate: _monthStart(month),
        endDate: _monthEnd(month),
        institutionId: _selectedInstitutionId,
      );

      // PDF font trenutno ne renderuje pouzdano dijakritike na svim sistemima -> ASCII fallback za naslov u PDF-u.
      final titleForPdf = '${_asciiBosnian(_reportFileBaseName(month, institution))}.';
      final period = '${_monthStart(month).day.toString().padLeft(2, '0')}.'
          '${_monthStart(month).month.toString().padLeft(2, '0')}.'
          '${_monthStart(month).year} - '
          '${_monthEnd(month).day.toString().padLeft(2, '0')}.'
          '${_monthEnd(month).month.toString().padLeft(2, '0')}.'
          '${_monthEnd(month).year}';

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(titleForPdf, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Period: $period'),
            pw.SizedBox(height: 16),
            pw.Text('Prodane karte po predstavi', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Predstava', 'Prodanih karata'],
              data: report.mostPopularShows
                  .map((s) => [s.showTitle, s.ticketsSold.toString()])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            ),
          ],
        ),
      );

      final fileName = '${_sanitizeFileName(_reportFileBaseName(month, institution))}.pdf';

      final dir = _defaultDownloadsDir();
      final filePath = dir.endsWith(Platform.pathSeparator) ? '$dir$fileName' : '$dir${Platform.pathSeparator}$fileName';
      await File(filePath).writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF preuzet: $filePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri preuzimanju: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Widget _buildChart() {
    final institution = _selectedInstitution;
    if (_selectedInstitutionId == null || institution == null) {
      return const Center(child: Text('Odaberite instituciju.'));
    }
    if (_loadingReport) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Greška: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_report == null || _report!.mostPopularShows.isEmpty) {
      return const Center(child: Text('Nema podataka za odabrani mjesec.'));
    }

    final shows = _report!.mostPopularShows;
    final top = shows.take(10).toList(); // keep chart readable
    final maxY = top.map((e) => e.ticketsSold).fold<int>(0, (p, c) => c > p ? c : p).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _reportTitle(_selectedMonth, institution.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: BarChart(
                BarChartData(
                  maxY: (maxY <= 0 ? 1 : (maxY * 1.15)),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 72,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= top.length) return const SizedBox.shrink();
                          final label = top[idx].showTitle;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: 70,
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(top.length, (i) {
                    final s = top[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: s.ticketsSold.toDouble(),
                          color: Colors.grey.shade700,
                          width: 18,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prikazano top ${top.length} predstava po prodanim kartama (za odabrani mjesec).',
              style: Theme.of(context).textTheme.bodySmall,
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
        title: const Text('Menadžerski izvještaji'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstitutions,
          ),
        ],
      ),
      body: _loadingInstitutions
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _institutions.isEmpty
              ? Center(child: Text('Greška: $_error', style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 360,
                            child: widget.fixedInstitutionId != null
                                ? InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Institucija',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      (_selectedInstitution?.name ?? '—'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : DropdownButtonFormField<int?>(
                                    value: _selectedInstitutionId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Institucija',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _institutions
                                        .map((i) => DropdownMenuItem<int?>(
                                              value: i.id,
                                              child: Text(i.name, overflow: TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (value) async {
                                      setState(() => _selectedInstitutionId = value);
                                      await _loadReport();
                                    },
                                  ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 320,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Pretražite po nazivu',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => setState(() => _searchController.clear()),
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 980;
                            final list = _filteredMonths;

                            Widget listPanel() => Card(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final m = list[idx];
                                      final label = _monthLabel(m);
                                      final selected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
                                      return ListTile(
                                        selected: selected,
                                        title: Text('Izvještaj za mjesec $label.'),
                                        onTap: () async {
                                          setState(() => _selectedMonth = DateTime(m.year, m.month, 1));
                                          await _loadReport();
                                        },
                                        trailing: ElevatedButton(
                                          onPressed: _selectedInstitutionId == null || _loadingReport
                                              ? null
                                              : () => _downloadPdfForMonth(m),
                                          child: const Text('Preuzmi'),
                                        ),
                                      );
                                    },
                                  ),
                                );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  SizedBox(height: 260, child: listPanel()),
                                  const SizedBox(height: 12),
                                  Expanded(child: _buildChart()),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                SizedBox(width: 520, child: listPanel()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildChart()),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

