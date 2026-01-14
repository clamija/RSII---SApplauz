import 'package:flutter/material.dart';
import '../../models/show.dart';
import '../../models/review.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/recommendations_cache_service.dart';

class ReviewScreen extends StatefulWidget {
  final int showId;
  final Show show;

  const ReviewScreen({
    super.key,
    required this.showId,
    required this.show,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _authService = AuthService();
  List<Review> _reviews = [];
  Review? _myReview;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _canReview = false;
  String _canReviewMessage = '';
  String? _error;

  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

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

      // Provjeri da li korisnik može ostaviti recenziju
      final canReviewInfo = await ApiService.canReviewShowInfo(widget.showId);
      _canReview = canReviewInfo['canReview'] == true;
      _canReviewMessage = (canReviewInfo['message']?.toString() ?? '').trim();

      // Učitaj recenzije
      final reviews = await ApiService.getReviews(showId: widget.showId);
      
      // Pronađi moju recenziju
      final currentUser = _authService.currentUser;
      Review? myReview;
      if (currentUser != null) {
        myReview = reviews.firstWhere(
          (r) => r.userId == currentUser.id,
          orElse: () => Review(
            id: 0,
            userId: currentUser.id,
            userName: currentUser.fullName,
            showId: widget.showId,
            showTitle: widget.show.title,
            rating: 0,
            isVisible: true,
            createdAt: DateTime.now(),
          ),
        );
        if (myReview.id == 0) {
          myReview = null;
        }
      }

      setState(() {
        _reviews = reviews.where((r) => r.isVisible).toList();
        _myReview = myReview;
        if (_myReview != null) {
          _selectedRating = _myReview!.rating;
          _commentController.text = _myReview!.comment ?? '';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Molimo odaberite ocjenu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final request = CreateReviewRequest(
        showId: widget.showId,
        rating: _selectedRating,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
      );

      await ApiService.createReview(request);

      // Invalidiraj cache preporuka nakon ostavljene recenzije
      await RecommendationsCacheService.invalidateCache();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_myReview == null ? 'Recenzija je uspješno kreirana' : 'Recenzija je uspješno ažurirana'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh data
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recenzije'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Greška: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.show.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.show.institutionName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // My review section
                      if (!_canReview && _myReview == null) ...[
                        Card(
                          color: Colors.blueGrey.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _canReviewMessage.isNotEmpty
                                  ? _canReviewMessage
                                  : 'Recenziju možete ostaviti samo ako ste kupili kartu za neki termin ove predstave, taj termin je završen i karta je skenirana.',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_canReview || _myReview != null) ...[
                        Text(
                          _myReview == null ? 'Ostavi recenziju' : 'Moja recenzija',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ocjena',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(5, (index) {
                                    final rating = index + 1;
                                    return GestureDetector(
                                      onTap: _canReview || _myReview != null
                                          ? () {
                                              setState(() {
                                                _selectedRating = rating;
                                              });
                                            }
                                          : null,
                                      child: Icon(
                                        rating <= _selectedRating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: rating <= _selectedRating
                                            ? Colors.amber
                                            : Colors.grey,
                                        size: 40,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Komentar (opcionalno)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _commentController,
                                  enabled: _canReview || _myReview != null,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    hintText: 'Ostavite svoj komentar...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_canReview || _myReview != null)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting ? null : _submitReview,
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Text(_myReview == null ? 'Pošalji recenziju' : 'Ažuriraj recenziju'),
                                    ),
                                  ),
                                if (!_canReview && _myReview == null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Možete ostaviti recenziju samo nakon što odgledate predstavu',
                                            style: TextStyle(color: Colors.orange),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Other reviews
                      const Text(
                        'Ostale recenzije',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_reviews.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Nema recenzija za ovu predstavu',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._reviews.map((review) => _buildReviewCard(review)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.comment!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${review.createdAt.day}.${review.createdAt.month}.${review.createdAt.year}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
