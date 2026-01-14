import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/ticket.dart';
import '../../services/api_service.dart';

class TicketQRScreen extends StatefulWidget {
  final Ticket ticket;

  const TicketQRScreen({super.key, required this.ticket});

  @override
  State<TicketQRScreen> createState() => _TicketQRScreenState();
}

class _TicketQRScreenState extends State<TicketQRScreen> {
  late Ticket _ticket;
  bool _isRefunding = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  Future<void> _handleRefund() async {
    if (_ticket.orderId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška: nije moguće odrediti narudžbu za ovu kartu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Potvrda refund-a
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrda refund-a'),
        content: Text(
          'Jeste li sigurni da želite refundirati narudžbu #${_ticket.orderId}?\n\n'
          'Refund će biti dozvoljen samo ako nijedna karta iz narudžbe nije skenirana.\n\n'
          'Novac će biti vraćen na vašu karticu u roku od 5-10 radnih dana.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Refundiraj'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRefunding = true);
    try {
      await ApiService.refundOrder(_ticket.orderId);

      // Osvježi kartu da se status odmah vidi kao Refundirana
      final refreshed = await ApiService.getTicketByQRCode(_ticket.qrCode);
      if (!mounted) return;
      setState(() {
        _ticket = refreshed;
        _isRefunding = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refund je uspješno obrađen. Novac će biti vraćen u roku od 5-10 radnih dana.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefunding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri refund-u: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _ticket.isScanned
        ? Colors.green
        : _ticket.isValid
            ? Colors.blue
            : Colors.red;

    final canRefund = !_ticket.isScanned && !_ticket.isRefunded && _ticket.status.toLowerCase() == 'notscanned';

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod karte'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Ticket info card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ticket.showTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ticket.institutionName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _ticket.formattedDate,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _ticket.formattedTime,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        _ticket.statusDisplayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (canRefund) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRefunding ? null : _handleRefund,
                          icon: _isRefunding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.money_off),
                          label: Text(_isRefunding ? 'Refund u toku...' : 'Refundiraj'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // QR Code
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _ticket.qrCode,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QR Kod: ${_ticket.qrCode.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Instructions
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Uputstvo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prikažite ovaj QR kod na ulazu u pozorište. Blagajnik će skenirati kod i validirati vašu kartu.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            if (_ticket.isScanned && _ticket.scannedAt != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Karta je skenirana: ${_formatDateTime(_ticket.scannedAt!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}.${local.month}.${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}






