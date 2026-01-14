import 'package:flutter/material.dart';
import '../../models/review.dart';
import '../../models/show.dart';
import '../../models/show_list_response.dart';
import '../../services/api_service.dart';

class ReviewsManagementScreen extends StatefulWidget {
  const ReviewsManagementScreen({super.key});

  @override
  State<ReviewsManagementScreen> createState() => _ReviewsManagementScreenState();
}

class _ReviewsManagementScreenState extends State<ReviewsManagementScreen> {
  List<Review> _reviews = [];
  List<Show> _shows = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedShowId;

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
      final results = await Future.wait([
        ApiService.getShowsForManagement(pageNumber: 1, pageSize: 100),
        ApiService.getReviewsForManagement(showId: _selectedShowId),
      ]);

      final showListResponse = results[0] as ShowListResponse;
      setState(() {
        _shows = showListResponse.shows;
        _reviews = results[1] as List<Review>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await ApiService.getReviewsForManagement(showId: _selectedShowId);
      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleVisibility(Review review) async {
    try {
      await ApiService.updateReviewVisibility(review.id, !review.isVisible);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !review.isVisible 
                  ? 'Recenzija je sada vidljiva' 
                  : 'Recenzija je sada sakrivena',
            ),
          ),
        );
        _loadReviews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje Recenzijama'),
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
                          _loadReviews();
                        },
                      ),
                    ),
                    Expanded(
                      child: _reviews.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.rate_review, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nema recenzija${_selectedShowId == null ? '' : ' za odabranu predstavu'}',
                                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadReviews,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: review.isVisible 
                                            ? Colors.green 
                                            : Colors.grey,
                                        child: Text(
                                          '${review.rating}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        review.userName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.showTitle,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                i < review.rating ? Icons.star : Icons.star_border,
                                                size: 16,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ),
                                          if (review.comment != null && review.comment!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              review.comment!,
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: PopupMenuButton(
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'visibility',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  review.isVisible ? Icons.visibility_off : Icons.visibility,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(review.isVisible ? 'Sakrij' : 'Prikaži'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'visibility') {
                                            _toggleVisibility(review);
                                          }
                                        },
                                      ),
                                      isThreeLine: review.comment != null && review.comment!.isNotEmpty,
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
