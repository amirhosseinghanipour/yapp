import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../domain/repositories/messenger_repository.dart';
import '../yapp_design.dart';
import 'chat_detail_screen.dart';

class ScanContactScreen extends StatefulWidget {
  const ScanContactScreen({super.key, required this.repository});

  final MessengerRepository repository;

  static const String payloadPrefix = 'yapp:user:';

  static String? usernameFrom(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith(payloadPrefix)) return null;
    final username = trimmed.substring(payloadPrefix.length).trim();
    if (username.isEmpty) return null;
    return username.toLowerCase();
  }

  @override
  State<ScanContactScreen> createState() => _ScanContactScreenState();
}

class _ScanContactScreenState extends State<ScanContactScreen> {
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

    final username = ScanContactScreen.usernameFrom(raw);
    if (username == null) {
      if (!mounted) return;
      setState(() => _error = "that isn't a yapp contact code");
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _done = true;
      final summary = await widget.repository.openChatByUsername(username);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatDetailScreen(chatId: summary.id, peer: summary.user),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = false;
        _error = '@$username not found on yapp';
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
        title: const Text('scan contact code'),
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
                  child: Text(_error!, style: Yapp.body(color: Yapp.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
