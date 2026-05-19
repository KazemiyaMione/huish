import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _binding = false;
  bool _done = false;
  bool _torch = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Try to extract a device ID from QR content.
  /// QR may contain: raw ID, URL with id=xxx, or other formats.
  String? _extractDeviceId(String code) {
    // Try as raw device ID (numeric string)
    if (RegExp(r'^\d{10,20}$').hasMatch(code)) return code;

    // Try as URL
    final uri = Uri.tryParse(code);
    if (uri != null) {
      // Query param: ?id=xxx
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) return id;
      // Query param: ?did=xxx
      final did = uri.queryParameters['did'];
      if (did != null && did.isNotEmpty) return did;
      // Last path segment might be the ID
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (RegExp(r'^\d{10,20}$').hasMatch(last)) return last;
      }
    }

    // Try to find a numeric ID anywhere in the string
    final match = RegExp(r'(\d{10,20})').firstMatch(code);
    return match?.group(1);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_binding || _done) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    final did = _extractDeviceId(code);
    if (did == null || did.isEmpty) return;

    setState(() => _binding = true);

    final api = context.read<AuthProvider>().api;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final resp = await api.getDeviceQr(did);
      if (!mounted) return;

      setState(() => _done = true);

      if (resp.isSuccess) {
        messenger.showSnackBar(
          const SnackBar(content: Text('设备添加成功'), backgroundColor: Colors.green),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        nav.pop(true);
      } else if (resp.code == 400 || resp.code == 409) {
        // Device already bound or invalid request
        messenger.showSnackBar(
          const SnackBar(content: Text('设备已在列表中或已绑定'), backgroundColor: Colors.orange),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        nav.pop(true); // still refresh the list
      } else {
        setState(() => _binding = false);
        messenger.showSnackBar(
          SnackBar(content: Text('绑定失败 (code: ${resp.code})，请重试')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _binding = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('网络异常，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码添加设备'),
        actions: [
          IconButton(
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _ctrl.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: _done ? Colors.green : Colors.blue, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_binding)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('正在绑定设备...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              '将二维码对准框内',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
