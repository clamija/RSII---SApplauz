import 'package:flutter/material.dart';
import '../../models/review.dart';
import '../../models/show.dart';
import '../../services/api_service.dart';

class ReviewsManagementScreen extends StatefulWidget {
  final int? institutionId;

  const ReviewsManagementScreen({super.key, this.institutionId});

  @override
  State<ReviewsManagementScreen> createState() => _ReviewsManagementScreenState();
}

class _ReviewsManagementScreenState extends State<ReviewsManagementScreen> {
  List<Review> _reviews = [];
  List<Show> _shows = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedShowId;
  int? _selectedRating;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final showsResp = await ApiService.getShowsForManagement(
        pageNumber: 1,
        pageSize: 1000,
        institutionId: widget.institutionId,
      );
      final shows = showsResp.shows;

      final effectiveShowId = (widget.institutionId != null && _selectedShowId == null && shows.isNotEmpty)
          ? shows.first.id
          : _selectedShowId;

      final reviews = await ApiService.getReviewsForManagement(
        showId: effectiveShowId,
        pageNumber: 1,
        pageSize: 1000,
      );

      setState(() {
        _shows = shows;
        _selectedShowId = effectiveShowId;
        _reviews = reviews;
        _reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVisibility(Review review) async {
    try {
      await ApiService.updateReviewVisibility(review.id, !review.isVisible);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            review.isVisible
                ? 'Recenzija sakrivena'
                : 'Recenzija prikazana',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteDialog(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje recenzije'),
        content: Text('Da li ste sigurni da želite obrisati recenziju korisnika "${review.userName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.deleteReview(review.id);
                if (!mounted) return;
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recenzija obrisana'),
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

  List<Review> get _filteredReviews {
    final searchTerm = _searchController.text.toLowerCase();
    
    return _reviews.where((r) {
      // Pretraga po Show-u, korisniku ili komentaru
      final matchesSearch = searchTerm.isEmpty ||
          r.userName.toLowerCase().contains(searchTerm) ||
          r.showTitle.toLowerCase().contains(searchTerm) ||
          (r.comment?.toLowerCase().contains(searchTerm) ?? false);
      
      // Filter po Show-u
      final matchesShow = _selectedShowId == null || r.showId == _selectedShowId;
      
      // Filter po ocjeni
      final matchesRating = _selectedRating == null || r.rating == _selectedRating;
      
      return matchesSearch && matchesShow && matchesRating;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje recenzijama'),
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
                final isNarrow = constraints.maxWidth < 860;

                final searchField = SizedBox(
                  width: isNarrow ? constraints.maxWidth : 520,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Pretraži recenzije...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                );

                final showFilter = SizedBox(
                  width: isNarrow ? constraints.maxWidth : 320,
                  child: DropdownButtonFormField<int?>(
                    value: _selectedShowId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Predstava',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sve predstave')),
                      ..._shows.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(s.title, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedShowId = value),
                  ),
                );

                final ratingFilter = SizedBox(
                  width: isNarrow ? constraints.maxWidth : 320,
                  child: DropdownButtonFormField<int?>(
                    value: _selectedRating,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ocjena',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sve ocjene')),
                      ...List.generate(5, (i) {
                        final rating = i + 1;
                        return DropdownMenuItem<int?>(
                          value: rating,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Row(
                              children: [
                                ...List.generate(5, (j) {
                                  return Icon(
                                    j < rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  );
                                }),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$rating ${rating == 1 ? 'zvijezda' : 'zvijezde'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _selectedRating = value),
                  ),
                );

                final hasFilters =
                    _searchController.text.isNotEmpty || _selectedShowId != null || _selectedRating != null;

                if (isNarrow) {
                  return Column(
                    children: [
                      Wrap(spacing: 16, runSpacing: 12, children: [searchField]),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          showFilter,
                          ratingFilter,
                          if (hasFilters)
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _selectedShowId = null;
                                  _selectedRating = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Očisti filtere'),
                            ),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(children: [Expanded(child: searchField)]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        showFilter,
                        const SizedBox(width: 16),
                        ratingFilter,
                        const Spacer(),
                        if (hasFilters)
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _selectedShowId = null;
                                _selectedRating = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Očisti filtere'),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Reviews list
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
                    : _filteredReviews.isEmpty
                        ? const Center(
                            child: Text('Nema recenzija'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredReviews.length,
                            itemBuilder: (context, index) {
                              final review = _filteredReviews[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: review.isVisible
                                        ? Colors.green
                                        : Colors.grey,
                                    child: const Icon(Icons.rate_review, color: Colors.white),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          review.userName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      ...List.generate(
                                        5,
                                        (i) => Icon(
                                          i < review.rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(review.showTitle),
                                      Text(
                                        'Datum: ${_formatDate(review.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (!review.isVisible)
                                        const Text(
                                          'Sakrivena',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  children: [
                                    if (review.comment != null && review.comment!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(review.comment!),
                                      ),
                                    OverflowBar(
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(
                                            review.isVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          label: Text(
                                            review.isVisible
                                                ? 'Sakrij'
                                                : 'Prikaži',
                                          ),
                                          onPressed: () => _toggleVisibility(review),
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          label: const Text(
                                            'Obriši',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onPressed: () => _showDeleteDialog(review),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

