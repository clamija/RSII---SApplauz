import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../models/show.dart';
import '../../models/performance.dart';
import '../../models/create_order_request.dart';
import '../../models/create_payment_intent_response.dart';
import '../../services/api_service.dart';
import '../../services/recommendations_cache_service.dart';
import '../tickets/my_tickets_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Performance performance;
  final Show show;

  const CheckoutScreen({
    super.key,
    required this.performance,
    required this.show,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _quantity = 1;
  bool _isSubmitting = false;
  bool _isProcessingPayment = false;
  String? _publishableKey;
  bool _stripeInitialized = false;
  int? _currentAvailableSeats; // Real-time dostupnost
  bool _isCheckingAvailability = false;

  int get _maxQuantity => _currentAvailableSeats ?? widget.performance.availableSeats;
  double get _totalPrice => widget.performance.price * _quantity;

  @override
  void initState() {
    super.initState();
    _currentAvailableSeats = widget.performance.availableSeats;
    _initializeStripe();
    _checkAvailability(); // Provjeri dostupnost pri učitavanju
  }

  Future<void> _initializeStripe() async {
    try {
      // Get publishable key from backend (we'll need to add this endpoint or get it from config)
      // For now, we'll use a placeholder - in production, get this from backend
      _publishableKey = 'pk_test_your_stripe_publishable_key';
      
      if (_publishableKey != null) {
        Stripe.publishableKey = _publishableKey!;
        await Stripe.instance.applySettings();
        setState(() {
          _stripeInitialized = true;
        });
      }
    } catch (e) {
      // Stripe initialization failed, but we can still create order without payment
      _stripeInitialized = false;
    }
  }

  Future<void> _checkAvailability() async {
    try {
      setState(() {
        _isCheckingAvailability = true;
      });
      
      // Real-time provjera dostupnosti
      final updatedPerformance = await ApiService.getPerformanceById(widget.performance.id);
      
      if (mounted) {
        setState(() {
          _currentAvailableSeats = updatedPerformance.availableSeats;
          _isCheckingAvailability = false;
          
          // Ako je količina veća od dostupne, smanji je
          if (_quantity > updatedPerformance.availableSeats) {
            _quantity = updatedPerformance.availableSeats;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  updatedPerformance.availableSeats == 0
                      ? 'Termin je sada rasprodan. Nema dostupnih karata.'
                      : 'Dostupnost je promijenjena. Sada je dostupno ${updatedPerformance.availableSeats} mjesta.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAvailability = false;
        });
      }
      // Ne prikazuj grešku - koristi staru vrijednost
    }
  }

  Future<void> _createOrder() async {
    // Prije kreiranja Order-a, provjeri dostupnost real-time
    await _checkAvailability();
    
    if (_currentAvailableSeats == null || _quantity > _currentAvailableSeats!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _currentAvailableSeats == 0
                ? 'Termin je rasprodan. Nema dostupnih karata.'
                : 'Dostupnost je promijenjena. Sada je dostupno samo $_currentAvailableSeats mjesta.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Količina mora biti veća od 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Pronađi institutionId iz show-a
      final request = CreateOrderRequest(
        institutionId: widget.show.institutionId,
        orderItems: [
          OrderItemRequest(
            performanceId: widget.performance.id,
            quantity: _quantity,
          ),
        ],
      );

      final order = await ApiService.createOrder(request);

      if (!mounted) return;

      final paymentSuccess = await _processPayment(order.id);
      if (!mounted) return;
      if (paymentSuccess) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Parsiranje greške za bolji prikaz
      final errorMessage = _parseErrorMessage(e.toString());
      
      // Provjeri da li je greška vezana za dostupnost
      if (errorMessage.contains('Neko je bio brži') || 
          errorMessage.contains('rasprodan') ||
          errorMessage.contains('dostupnih karata')) {
        // Osvježi dostupnost i prikaži dijalog
        await _checkAvailability();
        
        if (mounted) {
          _showAvailabilityErrorDialog(errorMessage);
        }
      } else {
        // Obična greška - prikaži SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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

  Future<bool> _processPayment(int orderId) async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Create payment intent
      final paymentIntent = await ApiService.createPaymentIntent(orderId);

      // (Re)initialize Stripe using publishable key from backend response
      _publishableKey = paymentIntent.publishableKey;
      if (_publishableKey != null && _publishableKey!.isNotEmpty) {
        Stripe.publishableKey = _publishableKey!;
        await Stripe.instance.applySettings();
        _stripeInitialized = true;
      }

      if (!_stripeInitialized || _publishableKey == null || _publishableKey!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plaćanje trenutno nije dostupno. Pokušajte ponovo kasnije.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: 'SApplauz',
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Confirm payment on backend
      final confirmedOrder = await ApiService.confirmPayment(orderId, paymentIntent.paymentIntentId);

      // Invalidiraj cache preporuka nakon kupovine karte
      await RecommendationsCacheService.invalidateCache();

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plaćanje uspješno!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      return true;
    } on StripeException catch (e) {
      if (!mounted) return false;

      String errorMessage = 'Greška pri plaćanju';
      if (e.error.code == FailureCode.Canceled) {
        errorMessage = 'Plaćanje otkazano';
      } else if (e.error.message != null) {
        errorMessage = e.error.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;

      // Parsiranje greške za bolji prikaz
      final errorMessage = _parseErrorMessage(e.toString());
      
      // Provjeri da li je greška vezana za dostupnost (race condition nakon plaćanja)
      if (errorMessage.contains('Neko je bio brži') || 
          errorMessage.contains('Plaćanje je uspješno') ||
          errorMessage.contains('rasprodan')) {
        
        // Ovo je kritična greška - plaćanje uspjelo ali karte nisu kreirane
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Plaćanje uspjelo'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorMessage),
                  const SizedBox(height: 16),
                  const Text(
                    'Vaše sredstva će biti vraćena automatski. Molimo kontaktirajte podršku ako imate pitanja.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Razumijem'),
                ),
              ],
            ),
          );
        }
      } else {
        // Obična greška pri plaćanju
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  String _parseErrorMessage(String error) {
    // Izdvoji poruku iz Exception stringa
    if (error.contains('Exception: ')) {
      return error.split('Exception: ').last.trim();
    }
    if (error.contains('InvalidOperationException: ')) {
      return error.split('InvalidOperationException: ').last.trim();
    }
    return error;
  }

  void _showAvailabilityErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Dostupnost promijenjena'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Neko je bio brži, nema dovoljno mjesta. Molimo osvježite stranicu.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Osvježi dostupnost
              _checkAvailability();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Osvježi dostupnost'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kupovina karata'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show info
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.performance.formattedDate} u ${widget.performance.formattedTime}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Quantity selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Količina',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Refresh button
                IconButton(
                  icon: _isCheckingAvailability
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isCheckingAvailability ? null : _checkAvailability,
                  tooltip: 'Osvježi dostupnost',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: (_quantity > 1 && !_isCheckingAvailability)
                          ? () {
                              setState(() {
                                _quantity--;
                              });
                            }
                          : null,
                    ),
                    Expanded(
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isCheckingAvailability)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Text(
                                'Dostupno: $_maxQuantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: (_quantity < _maxQuantity && !_isCheckingAvailability)
                          ? () {
                              setState(() {
                                _quantity++;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Price summary
            const Text(
              'Pregled narudžbe',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.performance.formattedPrice} x $_quantity',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          '${(widget.performance.price * _quantity).toStringAsFixed(2)} KM',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ukupno',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_totalPrice.toStringAsFixed(2)} KM',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 12),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isProcessingPayment) ? null : _createOrder,
                child: (_isSubmitting || _isProcessingPayment)
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        _stripeInitialized ? 'Kreiraj narudžbu i plati' : 'Kreiraj narudžbu',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




