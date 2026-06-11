import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../messages/presentation/yapp_design.dart';
import '../domain/repositories/auth_repository.dart';

class ScanLinkDeviceScreen extends StatefulWidget {
  const ScanLinkDeviceScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<ScanLinkDeviceScreen> createState() => _ScanLinkDeviceScreenState();
}

class _ScanLinkDeviceScreenState extends State<ScanLinkDeviceScreen> {
  bool _busy = false;
  bool _done = false;
  String? _error;
  final _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _done = true;
      await widget.repository.completeLinkDeviceFromBundle(raw);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? e.code.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('scan link code'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_busy)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Material(
                color: Yapp.paper,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: Yapp.body()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
