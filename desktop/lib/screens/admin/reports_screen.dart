import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/sales_report.dart';
import '../../models/popularity_report.dart';
import '../../services/api_service.dart';
import '../../models/institution.dart';
import '../../utils/role_helper.dart';
import '../../main.dart';
import '../../utils/theme_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SalesReport? _salesReport;
  PopularityReport? _popularityReport;
  bool _isLoading = false;
  String? _errorMessage;
  
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedInstitutionId;
  List<Institution> _institutions = [];
  bool _isSuperAdmin = false;

  final NumberFormat _km = NumberFormat.currency(locale: 'bs_BA', symbol: 'KM');

  String _formatKm(double value) => _km.format(value);

  String _formatPeriod(DateTime start, DateTime end) {
    final df = DateFormat('dd.MM.yyyy');
    return '${df.format(start)} - ${df.format(end)}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = globalAuthService.currentUser;
    _isSuperAdmin = user != null && RoleHelper.isSuperAdmin(user.roles);
    _loadInstitutions();
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutions() async {
    try {
      final institutions = await ApiService.getInstitutions();
      setState(() {
        _institutions = institutions;
        // SuperAdmin može vidjeti sve institucije, Admin vidi samo svoju (backend automatski filtrira)
        // Ako nije SuperAdmin, ne prikazuj dropdown za filtriranje po instituciji
        if (!_isSuperAdmin && institutions.length == 1) {
          _selectedInstitutionId = institutions.first.id;
        }
      });
    } catch (e) {
      // Ignoriraj greške pri učitavanju institucija
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final salesReport = await ApiService.getSalesReport(
        startDate: _startDate,
        endDate: _endDate,
        institutionId: _selectedInstitutionId,
      );
      
      final popularityReport = await ApiService.getPopularityReport(
        startDate: _startDate,
        endDate: _endDate,
        institutionId: _selectedInstitutionId,
      );

      setState(() {
        _salesReport = salesReport;
        _popularityReport = popularityReport;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final lastDate = now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      locale: const Locale('bs', 'BA'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izvještaji'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: 'Prodaja'),
            Tab(icon: Icon(Icons.trending_up), text: 'Popularnost'),
          ],
        ),
        actions: [
          if (_salesReport != null || _popularityReport != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportToPdf,
              tooltip: 'Preuzmi PDF izvještaj',
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filteri',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Osvježi',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Greška: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReports,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSalesReportTab(),
                    _buildPopularityReportTab(),
                  ],
                ),
    );
  }

  Widget _buildSalesReportTab() {
    if (_salesReport == null) {
      return const Center(child: Text('Nema podataka'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Ukupan Prihod',
                  _formatKm(_salesReport!.totalRevenue),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Ukupno Narudžbi',
                  _salesReport!.totalOrders.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Prodanih Karata',
                  _salesReport!.totalTicketsSold.toString(),
                  Icons.confirmation_number,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Date Range
          Text(
            'Period: ${_formatPeriod(_salesReport!.startDate, _salesReport!.endDate)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),

          // Daily Sales Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dnevna Prodaja',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildDailySalesChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sales by Institution
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prodaja po Institucijama',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildInstitutionSalesChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sales by Show Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Predstave po Prodaji',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSalesByShowTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularityReportTab() {
    if (_popularityReport == null) {
      return const Center(child: Text('Nema podataka'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Period: ${_formatPeriod(_popularityReport!.startDate, _popularityReport!.endDate)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),

          // Most Popular Shows
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Najpopularnije Predstave',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildPopularShowsChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Most Popular Genres
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Najpopularniji Žanrovi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildPopularGenresChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Most Popular Institutions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Najpopularnije Institucije',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildPopularInstitutionsTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySalesChart() {
    if (_salesReport == null || _salesReport!.dailySales.isEmpty) {
      return const Center(child: Text('Nema podataka za prikaz'));
    }

    final spots = _salesReport!.dailySales.map((sales) {
      return FlSpot(
        sales.date.millisecondsSinceEpoch.toDouble(),
        sales.revenue,
      );
    }).toList();

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Text(DateFormat('dd.MM').format(date), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  Widget _buildInstitutionSalesChart() {
    if (_salesReport == null || _salesReport!.salesByInstitution.isEmpty) {
      return const Center(child: Text('Nema podataka za prikaz'));
    }

    final bars = _salesReport!.salesByInstitution.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.revenue,
            color: Colors.blue,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: bars,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < _salesReport!.salesByInstitution.length) {
                  final name = _salesReport!.salesByInstitution[value.toInt()].institutionName;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      name.length > 15 ? '${name.substring(0, 15)}...' : name,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        alignment: BarChartAlignment.spaceAround,
      ),
    );
  }

  Widget _buildPopularShowsChart() {
    if (_popularityReport == null || _popularityReport!.mostPopularShows.isEmpty) {
      return const Center(child: Text('Nema podataka za prikaz'));
    }

    final bars = _popularityReport!.mostPopularShows.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.ticketsSold.toDouble(),
            color: Colors.green,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: bars,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < _popularityReport!.mostPopularShows.length) {
                  final title = _popularityReport!.mostPopularShows[value.toInt()].showTitle;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      title.length > 15 ? '${title.substring(0, 15)}...' : title,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        alignment: BarChartAlignment.spaceAround,
      ),
    );
  }

  Widget _buildPopularGenresChart() {
    if (_popularityReport == null || _popularityReport!.mostPopularGenres.isEmpty) {
      return const Center(child: Text('Nema podataka za prikaz'));
    }

    final colors = [
      Colors.blue,
      Colors.green,
      ThemeHelper.secondaryColor,
      ThemeHelper.primaryColor,
      ThemeHelper.tertiaryColor,
      ThemeHelper.secondaryColor,
      ThemeHelper.primaryColor,
      Colors.pink,
    ];

    final sections = _popularityReport!.mostPopularGenres.asMap().entries.map((entry) {
      return PieChartSectionData(
        value: entry.value.ticketsSold.toDouble(),
        title: '${entry.value.ticketsSold}',
        color: colors[entry.key % colors.length],
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildSalesByShowTable() {
    if (_salesReport == null || _salesReport!.salesByShow.isEmpty) {
      return const Center(child: Text('Nema podataka'));
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Predstava')),
        DataColumn(label: Text('Prihod')),  
        DataColumn(label: Text('Narudžbe')),
        DataColumn(label: Text('Karte')),
      ],
      rows: _salesReport!.salesByShow.take(10).map((s) {
        return DataRow(
          cells: [
            DataCell(Text(s.showTitle)),
            DataCell(Text(_formatKm(s.revenue))),
            DataCell(Text(s.ordersCount.toString())),
            DataCell(Text(s.ticketsSold.toString())),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPopularInstitutionsTable() {
    if (_popularityReport == null || _popularityReport!.mostPopularInstitutions.isEmpty) {
      return const Center(child: Text('Nema podataka'));
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Institucija')),
        DataColumn(label: Text('Predstave')),
        DataColumn(label: Text('Karte')),
        DataColumn(label: Text('Prihod')),
      ],
      rows: _popularityReport!.mostPopularInstitutions.map((i) {
        return DataRow(
          cells: [
            DataCell(Text(i.institutionName)),
            DataCell(Text(i.showsCount.toString())),
            DataCell(Text(i.ticketsSold.toString())),
            DataCell(Text(_formatKm(i.revenue))),
          ],
        );
      }).toList(),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filteri'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Period'),
                subtitle: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}'
                      : 'Nije odabran',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDateRange,
              ),
              if (_isSuperAdmin && _institutions.isNotEmpty)
                DropdownButtonFormField<int?>(
                  value: _selectedInstitutionId,
                  decoration: const InputDecoration(
                    labelText: 'Institucija',
                    border: OutlineInputBorder(),
                    helperText: 'SuperAdmin može filtrirati po instituciji',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sve institucije'),
                    ),
                    ..._institutions.map((i) => DropdownMenuItem<int?>(
                          value: i.id,
                          child: Text(i.name),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedInstitutionId = value;
                    });
                  },
                )
              else if (!_isSuperAdmin)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Admin vidi izvještaje samo za svoju instituciju',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                if (_isSuperAdmin) {
                  _selectedInstitutionId = null;
                }
              });
            },
            child: const Text('Resetuj'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadReports();
            },
            child: const Text('Primijeni'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (_salesReport == null && _popularityReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema podataka za izvoz'),
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd.MM.yyyy');
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'SApplauz - Izvještaji',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Datum generisanja: ${dateFormat.format(now)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              if (_startDate != null && _endDate != null)
                pw.Text(
                  'Period: ${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              pw.SizedBox(height: 20),
              if (_salesReport != null) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('Izvještaj o prodaji'),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Ukupan prihod: ${_formatKm(_salesReport!.totalRevenue)}'),
                pw.Text('Ukupno narudžbi: ${_salesReport!.totalOrders}'),
                pw.Text('Prodanih karata: ${_salesReport!.totalTicketsSold}'),
                pw.SizedBox(height: 20),
                if (_salesReport!.salesByShow.isNotEmpty) ...[
                  pw.Header(
                    level: 2,
                    child: pw.Text('Top predstave po prodaji'),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Predstava', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Prihod', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Karte', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ..._salesReport!.salesByShow.take(10).map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.showTitle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.revenue.toStringAsFixed(2)} KM'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.ticketsSold.toString()),
                          ),
                        ],
                      )),
                    ],
                  ),
                ],
              ],
              if (_popularityReport != null) ...[
                pw.SizedBox(height: 30),
                pw.Header(
                  level: 1,
                  child: pw.Text('Izvještaj o popularnosti'),
                ),
                pw.SizedBox(height: 10),
                if (_popularityReport!.mostPopularShows.isNotEmpty) ...[
                  pw.Header(
                    level: 2,
                    child: pw.Text('Najpopularnije predstave'),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Predstava', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Ocjena', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Recenzije', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ..._popularityReport!.mostPopularShows.take(10).map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.showTitle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text((item.averageRating ?? 0).toStringAsFixed(2)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.reviewsCount.toString()),
                          ),
                        ],
                      )),
                    ],
                  ),
                ],
              ],
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri generisanju PDF-a: ${e.toString()}'),
          ),
        );
      }
    }
  }
}

