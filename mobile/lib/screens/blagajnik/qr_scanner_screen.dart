import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/ticket.dart';
import '../../utils/role_helper.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  String? _lastScannedCode;
  Ticket? _lastTicket;
  String? _infoMessage;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isSuperAdmin = user != null && RoleHelper.isSuperAdmin(user.roles);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Validacija'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          if (isSuperAdmin)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SuperAdmin: Možete skenirati karte svih institucija',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            flex: 4,
            child: _buildQRView(context),
          ),
          Expanded(
            flex: 2,
            child: _buildResultSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildQRView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 250.0
        : 300.0;

    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.teal,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null && scanData.code != _lastScannedCode) {
        _lastScannedCode = scanData.code;
        _loadTicket(scanData.code!);
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Potrebna je dozvola za kameru'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadTicket(String qrCode) async {
    setState(() {
      _isProcessing = true;
      _lastTicket = null;
      _infoMessage = null;
    });

    try {
      final ticket = await ApiService.getTicketByQRCode(qrCode);
      setState(() {
        _lastTicket = ticket;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanTicket() async {
    final qrCode = _lastScannedCode;
    if (qrCode == null) return;

    setState(() {
      _isProcessing = true;
      _infoMessage = null;
    });

    try {
      final result = await ApiService.validateTicket(qrCode);
      setState(() {
        // Najtačniji status nakon validacije dobijamo iz response.ticket
        if (result.ticket != null) {
          _lastTicket = result.ticket;
        }
        _infoMessage = result.message;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _infoMessage = e.toString();
      });
    }
  }

  Widget _buildResultSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Validacije',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_isProcessing)
              const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Obrađujem QR kod...'),
                ],
              )
            else if (_lastTicket != null)
              _buildTicketStatusCard(_lastTicket!)
            else
              const Text(
                'Skenirajte QR kod karte',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketStatusCard(Ticket ticket) {
    final status = ticket.status.toLowerCase();
    final isNotScanned = status == 'notscanned';
    final isInvalid = status == 'invalid';
    final isScanned = status == 'scanned';
    final isRefunded = status == 'refunded';

    final currentUser = AuthService.instance.currentUser;
    final isSuperAdmin = currentUser != null && RoleHelper.isSuperAdmin(currentUser.roles);
    final currentInstitutionId = currentUser == null
        ? null
        : (currentUser.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(currentUser.roles));
    final sameInstitution = currentInstitutionId != null && ticket.institutionId == currentInstitutionId;

    // Time window: 120 min prije i 15 min nakon početka predstave
    final nowUtc = DateTime.now().toUtc();
    final startUtc = ticket.performanceStartTime.isUtc
        ? ticket.performanceStartTime
        : ticket.performanceStartTime.toUtc();
    final validFrom = startUtc.subtract(const Duration(minutes: 120));
    final validTo = startUtc.add(const Duration(minutes: 15));
    final withinWindow = nowUtc.isAfter(validFrom) && nowUtc.isBefore(validTo);

    final statusText = isNotScanned
        ? 'važeća'
        : isInvalid
            ? 'nevažeća'
            : isScanned
                ? 'skenirana'
                : isRefunded
                    ? 'refundirana'
                : ticket.status;

    final canScan = isNotScanned && withinWindow && (isSuperAdmin || sameInstitution);

    String? timeWindowMessage;
    if (isNotScanned && !withinWindow) {
      if (nowUtc.isBefore(validFrom)) {
        timeWindowMessage =
            'Karta može biti skenirana najranije 120 minuta prije početka predstave.';
      } else if (nowUtc.isAfter(validTo)) {
        timeWindowMessage =
            'Karta je istekla (prošlo je više od 15 minuta od početka predstave).';
      }
    }

    String? institutionMessage;
    // Poruku o instituciji prikazujemo samo ako je karta važeća (NotScanned) ali iz druge institucije.
    // Ako je već nevažeća/skenirana, ne zatrpavaj UI dodatnom porukom.
    if (isNotScanned && !isSuperAdmin && !sameInstitution) {
      institutionMessage =
          'Ovu kartu može skenirati samo blagajnik institucije: ${ticket.institutionName}.';
    }

    final userLine = (ticket.userFullName.trim().isNotEmpty)
        ? ticket.userFullName.trim()
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Prikazana karta korisnika: $userLine',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          ticket.institutionName,
          style: TextStyle(color: Colors.grey[700]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          ticket.showTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text('${ticket.formattedDate}  •  ${ticket.formattedTime}'),
        const SizedBox(height: 12),
        Text(
          'Status karte: $statusText.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: (isInvalid || isRefunded) ? Colors.red : (isScanned ? Colors.blueGrey : Colors.green),
          ),
        ),
        if ((institutionMessage?.isNotEmpty ?? false) ||
            (timeWindowMessage?.isNotEmpty ?? false) ||
            (_infoMessage?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          Text(
            (institutionMessage?.isNotEmpty ?? false)
                ? institutionMessage!
                : (timeWindowMessage?.isNotEmpty ?? false)
                    ? timeWindowMessage!
                    : (_infoMessage ?? ''),
            style: TextStyle(color: isInvalid ? Colors.red : Colors.black87),
          ),
        ],
        const SizedBox(height: 12),
        if (canScan)
          ElevatedButton(
            onPressed: _scanTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Skeniraj kartu'),
          ),
        if (!canScan && isInvalid)
          Text(
            'Obavijestite korisnika da nažalost niste u mogućnosti skenirati kartu jer je predstava već u toku.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}



