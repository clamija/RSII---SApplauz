import 'package:flutter/material.dart';
import '../../models/show.dart';
import '../../models/performance.dart';
import '../../services/api_service.dart';
import '../../utils/theme_helper.dart';
import '../../widgets/show_image_widget.dart';
import '../checkout/checkout_screen.dart';
import '../reviews/review_screen.dart';

class ShowDetailsScreen extends StatefulWidget {
  final int showId;

  const ShowDetailsScreen({super.key, required this.showId});

  @override
  State<ShowDetailsScreen> createState() => _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends State<ShowDetailsScreen> {
  Show? _show;
  List<Performance> _performances = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShowDetails();
  }

  Future<void> _loadShowDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final show = await ApiService.getShowById(widget.showId);
      final performances = await ApiService.getPerformances(showId: widget.showId);

      setState(() {
        _show = show;
        // Prikaži buduće termine i trenutno aktivne termine
        final now = DateTime.now();
        final duration = show.durationMinutes;
        _performances = performances
            .where((p) {
              // Prikaži ako je budući termin ili trenutno aktivan
              final endTime = p.startTime.add(Duration(minutes: duration));
              return p.startTime.isAfter(now) || (p.startTime.isBefore(now) && endTime.isAfter(now));
            })
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
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
        title: const Text('Detalji predstave'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _show == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Greška pri učitavanju',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadShowDetails,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeHelper.secondaryColor,
                  ThemeHelper.primaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _show!.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _show!.institutionName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewScreen(
                          showId: widget.showId,
                          show: _show!,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        _show!.averageRating != null
                            ? '${_show!.averageRating!.toStringAsFixed(1)} (${_show!.reviewsCount} recenzija)'
                            : 'Recenzije i ocjenjivanje',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Show details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show image
                ShowImageWidget(
                  imagePath: _show!.resolvedImagePath ?? _show!.imagePath,
                  institutionImagePath: null, // Will be resolved by ImageHelper
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 16),
                if (_show!.description != null && _show!.description!.isNotEmpty) ...[
                  const Text(
                    'Opis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _show!.description!,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                ],
                // Info chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.access_time,
                      _show!.durationFormatted,
                    ),
                    _buildInfoChip(
                      Icons.category,
                      _show!.genresString,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Performances section
                const Text(
                  'Dostupni termini',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_performances.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Nema dostupnih termina',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._performances.map((performance) => _buildPerformanceCard(performance)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildPerformanceCard(Performance performance) {
    // Koristi status i statusColor iz backend-a ako postoje, inače izračunaj lokalno
    final isCurrentlyShowing = performance.isCurrentlyShowing(_show!.durationMinutes);
    final isSoldOut = performance.isSoldOut;
    final isAlmostSoldOut = performance.isAlmostSoldOut;
    
    // Koristi ThemeHelper za status boje
    final statusColor = ThemeHelper.getPerformanceStatusColor(
      isSoldOut: isSoldOut,
      isAlmostSoldOut: isAlmostSoldOut,
      isCurrentlyShowing: isCurrentlyShowing,
    );
    final statusText = ThemeHelper.getPerformanceStatusText(
      isSoldOut: isSoldOut,
      isAlmostSoldOut: isAlmostSoldOut,
      isCurrentlyShowing: isCurrentlyShowing,
    );
    final statusIcon = ThemeHelper.getPerformanceStatusIcon(
      isSoldOut: isSoldOut,
      isAlmostSoldOut: isAlmostSoldOut,
      isCurrentlyShowing: isCurrentlyShowing,
    );
    
    // Određivanje boje border-a i pozadine na osnovu statusa
    final borderColor = statusColor;
    final backgroundColor = statusColor.withValues(alpha: 0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2.5),
      ),
      child: InkWell(
        onTap: isSoldOut
            ? null
            : () {
                if (isCurrentlyShowing) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ova predstava se upravo izvodi. Molimo odaberite drugi termin.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      performance: performance,
                      show: _show!,
                    ),
                  ),
                ).then((_) {
                  _loadShowDetails(); // Refresh after checkout
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Date/Time
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeHelper.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      performance.formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      performance.formattedTime,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      performance.formattedPrice,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${performance.availableSeats} mjesta',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status badge sa ikonom
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: borderColor),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: borderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action icon
              if (!isSoldOut && !isCurrentlyShowing)
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.primary,
                )
              else if (isCurrentlyShowing)
                Icon(
                  Icons.play_circle_outline,
                  color: ThemeHelper.secondaryColor,
                  size: 28,
                )
              else
                Icon(
                  Icons.event_busy,
                  color: ThemeHelper.primaryColor,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}






