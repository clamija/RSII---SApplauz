import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/show.dart';
import '../../models/institution.dart';
import '../../models/genre.dart';
import '../../models/show_list_response.dart';
import '../../services/api_service.dart';
import '../../utils/image_helper.dart';
import '../../widgets/show_image_widget.dart';
import 'show_details_screen.dart';

class ShowsListScreen extends StatefulWidget {
  const ShowsListScreen({super.key});

  @override
  State<ShowsListScreen> createState() => _ShowsListScreenState();
}

class _ShowsListScreenState extends State<ShowsListScreen> {
  List<Show> _shows = [];
  List<Institution> _institutions = [];
  List<Genre> _genres = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  bool _hasMore = true;

  int? _selectedInstitutionId;
  int? _selectedGenreId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Real-time pretraga sa debounce-om (da ne spamamo API na svaki znak).
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyFilters();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Učitaj institucije i žanrove paralelno
      final institutionsFuture = ApiService.getInstitutions();
      final genresFuture = ApiService.getGenres();
      
      final results = await Future.wait([institutionsFuture, genresFuture]);
      _institutions = results[0] as List<Institution>;
      _genres = results[1] as List<Genre>;

      await _loadShows();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadShows({bool loadMore = false}) async {
    try {
      if (loadMore) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      final response = await ApiService.getShows(
        pageNumber: _currentPage,
        pageSize: _pageSize,
        institutionId: _selectedInstitutionId,
        genreId: _selectedGenreId,
        searchTerm: _searchController.text.isEmpty ? null : _searchController.text,
      );

      setState(() {
        if (loadMore) {
          _shows.addAll(response.shows);
        } else {
          _shows = response.shows;
        }
        _totalCount = response.totalCount;
        _hasMore = response.shows.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
    });
    _loadShows();
  }

  void _resetFilters() {
    setState(() {
      _selectedInstitutionId = null;
      _selectedGenreId = null;
      _searchController.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    _loadShows();
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      setState(() {
        _currentPage++;
      });
      _loadShows(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predstave'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Greška: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    if (_shows.isEmpty) {
      final hasFilters = _selectedInstitutionId != null || 
                         _selectedGenreId != null || 
                         _searchController.text.isNotEmpty;
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.theaters, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              hasFilters 
                  ? 'Nema rezultata za odabrane filtere'
                  : 'Nema dostupnih predstava',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              const Text(
                'Pokušajte promijeniti filtere ili pretragu',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Resetuj filtere'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Pretraži predstave...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // onChanged se hvata preko listenera + debounce
          ),
        ),
        // Active filters
        if (_selectedInstitutionId != null || _selectedGenreId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (_selectedInstitutionId != null)
                  Chip(
                    label: Text(
                      _institutions.firstWhere((i) => i.id == _selectedInstitutionId).name,
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedInstitutionId = null;
                      });
                      _applyFilters();
                    },
                  ),
                if (_selectedGenreId != null)
                  Chip(
                    label: Text(
                      _genres.firstWhere((g) => g.id == _selectedGenreId).name,
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedGenreId = null;
                      });
                      _applyFilters();
                    },
                  ),
              ],
            ),
          ),
        // Shows list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _currentPage = 1;
                _hasMore = true;
              });
              await _loadShows();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  final metrics = notification.metrics;
                  if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                    _loadMore();
                  }
                }
                return false;
              },
              child: ListView.builder(
                itemCount: _shows.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _shows.length) {
                    return _hasMore
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }

                  final show = _shows[index];
                  return _buildShowCard(show);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShowCard(Show show) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(showId: show.id),
            ),
          ).then((_) {
            // Refresh list after returning from details
            _loadShows();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show image
                  ShowImageWidget(
                    imagePath: show.resolvedImagePath ?? show.imagePath,
                    institutionImagePath: null, // Backend već vraća resolvedImagePath sa fallback logikom
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
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
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(show.durationFormatted),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                  ),
                  if (show.genres.isNotEmpty)
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filteri'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int?>(
                value: _selectedInstitutionId,
                decoration: const InputDecoration(
                  labelText: 'Institucija',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sve institucije')),
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
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _selectedGenreId,
                decoration: const InputDecoration(
                  labelText: 'Žanr',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Svi žanrovi')),
                  ..._genres.map((g) => DropdownMenuItem<int?>(
                        value: g.id,
                        child: Text(g.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGenreId = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetFilters();
            },
            child: const Text('Resetuj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Primijeni'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}






