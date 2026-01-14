import 'package:flutter/material.dart';
import '../../models/recommendation.dart';
import '../../models/show.dart';
import '../../services/api_service.dart';
import '../../services/recommendations_cache_service.dart';
import '../shows/show_details_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<Recommendation> _recommendations = [];
  List<Show> _popularShows = []; // Za cold start
  bool _isLoading = true;
  bool _isLoadingFromCache = false;
  bool _isColdStart = false; // Da li prikazujemo popularne predstave
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  /// Učitava preporuke iz cache-a ili API-ja.
  /// Ako forceRefresh = true, preskače cache i učitava direktno iz API-ja.
  /// Ako nema cache ili je cache stario, učitava iz API-ja.
  /// Ako API vraća praznu listu, poziva cold start handling.
  /// 
  /// [forceRefresh] - Ako je true, preskače cache i učitava direktno iz API-ja
  Future<void> _loadRecommendations({bool forceRefresh = false}) async {
    // Provjeri cache prije API poziva
    if (!forceRefresh) {
      final cachedRecommendations = await RecommendationsCacheService.getCachedRecommendations();
      
      if (cachedRecommendations != null && cachedRecommendations.isNotEmpty) {
        // Cache postoji i nije stario - prikaži keširane preporuke
        setState(() {
          _recommendations = cachedRecommendations;
          _isLoading = false;
          _isLoadingFromCache = true;
          _isColdStart = false;
        });

        // U pozadini osvježi preporuke ako je cache stario
        final isCacheValid = await RecommendationsCacheService.isCacheValid();
        if (!isCacheValid) {
          _refreshRecommendationsInBackground();
        }
        return;
      }
    }

    // Nema cache ili je force refresh - učitaj iz API-ja
    setState(() {
      _isLoading = true;
      _isLoadingFromCache = false;
      _errorMessage = null;
    });

    try {
      final recommendations = await ApiService.getRecommendations(count: 10);
      
      if (recommendations.isEmpty) {
        // Nema preporuka - provjeri cold start
        await _handleColdStart();
        return;
      }

      // Sačuvaj u cache
      await RecommendationsCacheService.saveRecommendations(recommendations);
      
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
        _isColdStart = false;
      });
    } catch (e) {
      // Ako API poziv ne uspije, provjeri cold start
      await _handleColdStart();
    }
  }

  /// Osvježava preporuke u pozadini bez blokiranja UI-ja.
  /// Koristi se kada je cache validan ali stariji od TTL-a.
  /// Ako osvježavanje uspije, ažurira UI sa novim preporukama.
  Future<void> _refreshRecommendationsInBackground() async {
    try {
      final recommendations = await ApiService.getRecommendations(count: 10);
      if (recommendations.isNotEmpty) {
        await RecommendationsCacheService.saveRecommendations(recommendations);
        if (mounted) {
          setState(() {
            _recommendations = recommendations;
            _isLoadingFromCache = false;
          });
        }
      }
    } catch (e) {
      // Ignoriši greške u pozadini
    }
  }

  /// Rješava cold start problem prikazivanjem popularnih predstava.
  /// Poziva se kada korisnik nema historiju kupovine karata ili recenzija.
  /// Učitava sve aktivne predstave i sortira ih po prosječnoj ocjeni i broju termina.
  /// Prikazuje poruku korisniku da počne sa gledanjem predstava za personalizovane preporuke.
  Future<void> _handleColdStart() async {
    try {
      // Pokušaj učitati popularne predstave (sortirane po averageRating ili performancesCount)
      final showsResponse = await ApiService.getShows(
        pageNumber: 1,
        pageSize: 10,
      );

      final popularShows = showsResponse.shows
          .where((show) => show.isActive)
          .toList()
        ..sort((a, b) {
          // Sortiraj po averageRating (ako postoji), zatim po performancesCount
          if (a.averageRating != null && b.averageRating != null) {
            return b.averageRating!.compareTo(a.averageRating!);
          }
          if (a.averageRating != null) return -1;
          if (b.averageRating != null) return 1;
          return b.performancesCount.compareTo(a.performancesCount);
        });

      if (mounted) {
        setState(() {
          _popularShows = popularShows.take(10).toList();
          _isColdStart = true;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isColdStart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preporuke za vas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadRecommendations(forceRefresh: true),
            tooltip: 'Osvježi preporuke',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && !_isColdStart) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Greška pri učitavanju preporuka',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadRecommendations(forceRefresh: true),
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    // Cold start - prikaži popularne predstave
    if (_isColdStart && _popularShows.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadRecommendations(forceRefresh: true),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cold start poruka
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Počnite sa gledanjem predstava',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kako biste dobili personalizovane preporuke, kupite karte ili ostavite recenzije.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Popularne predstave
              Text(
                'Popularne predstave',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._popularShows.map((show) => _buildShowCard(show)),
            ],
          ),
        ),
      );
    }

    if (_recommendations.isEmpty && !_isColdStart) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.recommend, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Nema preporuka',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Kupite karte ili ostavite recenzije da biste dobili personalizovane preporuke.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadRecommendations(forceRefresh: true),
              child: const Text('Osvježi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRecommendations(forceRefresh: true),
      child: Column(
        children: [
          // Cache indicator
          if (_isLoadingFromCache)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Osvježavanje preporuka...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final recommendation = _recommendations[index];
                return _buildRecommendationCard(recommendation);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Kreira widget za prikaz popularne predstave u cold start scenariju.
  /// Prikazuje naziv, instituciju, ocjenu, žanrove i broj termina.
  /// 
  /// [show] - Predstava koja se prikazuje
  Widget _buildShowCard(Show show) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(showId: show.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (show.institutionName.isNotEmpty)
                          Text(
                            show.institutionName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (show.averageRating != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            show.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (show.description != null && show.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  show.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(show.genresString),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                  ),
                  if (show.performancesCount > 0)
                    Chip(
                      label: Text('${show.performancesCount} termina'),
                      labelStyle: const TextStyle(fontSize: 12),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kreira widget za prikaz personalizovane preporuke.
  /// Prikazuje naziv predstave, score badge (procenat), razlog preporuke,
  /// žanrove, ocjenu i trajanje predstave.
  /// Score badge ima boju na osnovu score-a:
  /// - Zelena: Score >= 0.7
  /// - Narandžasta: Score >= 0.4
  /// - Plava: Score < 0.4
  /// 
  /// [recommendation] - Preporuka koja se prikazuje
  Widget _buildRecommendationCard(Recommendation recommendation) {
    final show = recommendation.show;
    final score = recommendation.score;
    final reason = recommendation.reason;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(showId: show.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (show.institutionName.isNotEmpty)
                          Text(
                            show.institutionName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getScoreColor(score),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(score * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Reason
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (show.description != null && show.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  show.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Genres
              if (show.genres.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: show.genres.map((genre) {
                    return Chip(
                      label: Text(genre.name),
                      labelStyle: const TextStyle(fontSize: 12),
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              // Rating and duration
              Row(
                children: [
                  if (show.averageRating != null) ...[
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      show.averageRating!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${show.durationMinutes} min',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vraća boju za score badge na osnovu score-a.
  /// 
  /// [score] - Score preporuke (0.0 - 1.0)
  /// 
  /// Returns:
  /// - Colors.green ako je score >= 0.7
  /// - Colors.orange ako je score >= 0.4
  /// - Colors.blue ako je score < 0.4
  Color _getScoreColor(double score) {
    if (score >= 0.7) {
      return Colors.green;
    } else if (score >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }
}






