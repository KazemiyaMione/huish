import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _codeCtrl = TextEditingController();
  final MobileScannerController _scanCtrl = MobileScannerController();
  bool _torch = false;
  bool _scanning = false;

  // Result state
  Map<String, dynamic>? _resultData;
  bool _loading = false;
  bool _favorited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  /// Try to extract a device ID from QR content.
  String? _extractDeviceId(String code) {
    if (RegExp(r'^\d{10,20}$').hasMatch(code)) return code;
    final uri = Uri.tryParse(code);
    if (uri != null) {
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) return id;
      final did = uri.queryParameters['did'];
      if (did != null && did.isNotEmpty) return did;
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty && RegExp(r'^\d{10,20}$').hasMatch(segments.last)) {
        return segments.last;
      }
    }
    final match = RegExp(r'(\d{10,20})').firstMatch(code);
    return match?.group(1);
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (_scanning || _resultData != null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    final did = _extractDeviceId(code);
    if (did == null) return;
    setState(() => _scanning = true);
    await _lookupDevice(did);
  }

  Future<void> _onManualLookup() async {
    final did = _codeCtrl.text.trim();
    if (did.isEmpty) return;
    setState(() => _scanning = true);
    await _lookupDevice(did);
  }

  Future<void> _lookupDevice(String did) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.getDeviceQr(did);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _resultData = resp.dataMap;
          _loading = false;
          _scanning = false;
        });
      } else if (resp.code == 400 || resp.code == 409) {
        setState(() {
          _error = '设备已在列表中或已绑定';
          _loading = false;
          _scanning = false;
          _favorited = true;
        });
      } else {
        setState(() {
          _error = resp.dataMap?['msg'] as String? ?? '未找到设备 (code: ${resp.code})';
          _loading = false;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '网络异常，请重试';
          _loading = false;
          _scanning = false;
        });
      }
    }
  }

  Future<void> _favoriteDevice() async {
    final dev = _resultData?['dev'] as Map<String, dynamic>?;
    final did = dev?['id'] as String?;
    if (did == null) return;
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.favoriteDevice(did);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() => _favorited = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已收藏设备'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏失败 (code: ${resp.code})')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _resultData = null;
      _error = null;
      _loading = false;
      _scanning = false;
      _favorited = false;
      _codeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加设备'),
        bottom: _resultData == null && !_loading
            ? TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_scanner), text: '扫码'),
                  Tab(icon: Icon(Icons.keyboard), text: '手动输入'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在查找设备...'),
          ],
        ),
      );
    }

    if (_resultData != null) return _buildResult();
    if (_error != null) return _buildError();

    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildScanTab(),
        _buildManualTab(),
      ],
    );
  }

  Widget _buildScanTab() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanCtrl,
          onDetect: _onScan,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 3),
              borderRadius: BorderRadius.circular(16),
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
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () async {
              await _scanCtrl.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
        ),
        if (_scanning)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('正在查找设备...', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildManualTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.numbers, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text('输入设备码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '设备码',
              hintText: '请输入设备码',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _onManualLookup(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _onManualLookup,
              icon: const Icon(Icons.search),
              label: const Text('查找设备'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final data = _resultData!;
    final dev = data['dev'] as Map<String, dynamic>?;
    final devName = dev?['name'] as String? ?? '未知设备';
    final devId = dev?['id'] as String? ?? '';
    final addr = dev?['addr'] as Map<String, dynamic>?;
    final detail = addr?['detail'] as String? ?? '';
    final qr = data['qr'] as Map<String, dynamic>?;
    final qrType = qr?['type'] as int? ?? 0;

    final typeLabel = switch (qrType) {
      2 => '饮水设备',
      3 => '扫码设备',
      _ => '设备',
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(
            _favorited ? Icons.check_circle : Icons.water_drop,
            size: 64,
            color: _favorited ? Colors.green : Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            _favorited ? '绑定成功' : '找到设备',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _infoRow('设备名称', devName),
                  const Divider(),
                  _infoRow('设备ID', devId),
                  if (detail.isNotEmpty) ...[
                    const Divider(),
                    _infoRow('位置', detail),
                  ],
                  const Divider(),
                  _infoRow('类型', typeLabel),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_favorited)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _favoriteDevice,
                icon: const Icon(Icons.favorite),
                label: const Text('收藏设备'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('继续添加'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange[400]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('重试'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
