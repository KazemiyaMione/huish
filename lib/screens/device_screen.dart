import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DeviceResult {
  final bool running;
  const DeviceResult({required this.running});
}

class DeviceScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final bool initiallyRunning;

  const DeviceScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.initiallyRunning = false,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  Map<String, dynamic>? _homeData;
  Map<String, dynamic>? _statusData;
  bool _loading = true;
  String? _error;
  double _currentOut = 0;
  double _startOut = 0;
  bool _running = false;
  bool _skipDetect = false;
  int _selectedPtype = 21;
  List<Map<String, dynamic>> _payItems = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _running = widget.initiallyRunning;
    _loadData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final homeResp = await api.getDeviceHome(widget.deviceId);
      if (!homeResp.isSuccess) {
        setState(() {
          _error = '加载设备数据失败 (code: ${homeResp.code})';
          _loading = false;
        });
        return;
      }
      final statusResp = await api.getDeviceStatus(widget.deviceId);
      if (!statusResp.isSuccess) {
        setState(() {
          _error = '加载状态失败 (code: ${statusResp.code})';
          _loading = false;
        });
        return;
      }
      setState(() {
        _homeData = homeResp.dataMap;
        _statusData = statusResp.dataMap;
        _loading = false;
      });
      _parseStatus();
      _parsePayItems();
      if (_running) _startPolling();
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.getDeviceStatus(widget.deviceId);
      if (!mounted) return;
      if (resp.isSuccess) {
        final device = resp.dataMap?['device'] as Map<String, dynamic>?;
        final gene = device?['gene'] as Map<String, dynamic>?;
        setState(() {
          _statusData = resp.dataMap;
          if (gene != null) {
            _currentOut = (gene['out'] as num?)?.toDouble() ?? _currentOut;
            // gene.status: 1 = dispensing, 99 = idle
            // gene.mode and vel are NOT reliable (both stay 0 / 1.2 regardless)
            final status = gene['status'] as int? ?? 99;
            if (status != 1) {
              _running = false;
              _stopPolling();
            }
          }
        });
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollStatus());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _parseStatus() {
    final device = _statusData?['device'] as Map<String, dynamic>?;
    final gene = device?['gene'] as Map<String, dynamic>?;
    if (gene != null) {
      _currentOut = (gene['out'] as num?)?.toDouble() ?? _currentOut;
      if (_skipDetect) return;
      final status = gene['status'] as int? ?? 99;
      // gene.status: 1 = dispensing, 99 = idle
      _running = status == 1;
      if (_running) {
        _startOut = _currentOut;
      }
    }
  }

  void _parsePayItems() {
    final raw = _homeData?['payItems'] as List<dynamic>?;
    if (raw != null) {
      _payItems = raw.cast<Map<String, dynamic>>();
      if (_payItems.isNotEmpty) {
        _payItems.sort((a, b) => (b['seq'] as int?)?.compareTo(a['seq'] as int? ?? 0) ?? 0);
        _selectedPtype = _payItems.first['type'] as int? ?? 21;
      }
    }
  }

  Future<void> _startDevice() async {
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.startDevice(widget.deviceId, ptype: _selectedPtype);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _running = true;
          _startOut = _currentOut;
        });
        _startPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已启动'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败 (code: ${resp.code})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败: $e')),
        );
      }
    }
  }

  Future<void> _stopDevice() async {
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.stopDevice(widget.deviceId).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _running = false;
        _stopPolling();
        _skipDetect = true;
      });
      if (resp.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已停止')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设备已关闭')),
        );
      }
      Future.delayed(const Duration(seconds: 2), () {
        _skipDetect = false;
        if (mounted) _loadData();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _stopPolling();
          _skipDetect = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已关闭（网络异常）')),
        );
        Future.delayed(const Duration(seconds: 2), () {
          _skipDetect = false;
          if (mounted) _loadData();
        });
      }
    }
  }

  Future<bool> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停止取水'),
        content: const Text('确定要停止取水吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(DeviceResult(running: _running));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.deviceName),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }

    final device = _homeData?['device'] as Map<String, dynamic>?;
    final addr = device?['addr'] as Map<String, dynamic>?;
    final detail = addr?['detail'] as String? ?? '';
    final bm = device?['bm'] as Map<String, dynamic>?;
    final unit = bm?['unit'] as String? ?? '升';
    final brand = bm?['brand'] as String? ?? '';
    final model = bm?['model'] as String? ?? '';
    final wallet = _homeData?['wallet'] as Map<String, dynamic>?;
    final balance = (wallet?['olCash'] as num?)?.toDouble() ?? 0;
    final thisUse = _currentOut - _startOut;

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _running ? Icons.water_drop : Icons.water_drop_outlined,
                    key: ValueKey(_running),
                    size: 64,
                    color: _running ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _running ? '正在取水中...' : '已停止',
                    key: ValueKey(_running),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _running ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_running) ...[
                  const SizedBox(height: 4),
                  Text(
                    '实时监测中',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary.withAlpha(180)),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat(theme, '累计出水', '${_currentOut.toStringAsFixed(1)} $unit'),
                    if (_running && thisUse > 0)
                      _buildStat(theme, '本次接水', '${thisUse.toStringAsFixed(1)} $unit')
                    else
                      _buildStat(theme, '余额', '¥${balance.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_payItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text('计费方式：', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: _payItems.map((p) {
                          final ptype = p['type'] as int? ?? 0;
                          final selected = _selectedPtype == ptype;
                          return ChoiceChip(
                            label: Text(_payTypeLabel(ptype)),
                            selected: selected,
                            onSelected: _running ? null : (_) => setState(() => _selectedPtype = ptype),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _running ? null : _startDevice,
            icon: const Icon(Icons.play_arrow, size: 32),
            label: const Text('开始取水', style: TextStyle(fontSize: 18)),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _running
                ? () async {
                    if (await _confirmStop()) _stopDevice();
                  }
                : null,
            icon: const Icon(Icons.stop, size: 32),
            label: const Text('停止取水', style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(
              backgroundColor: _running ? theme.colorScheme.error : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: _running ? theme.colorScheme.onError : theme.colorScheme.onSurface,
            ),
          ),
        ),

        if (brand.isNotEmpty || model.isNotEmpty) ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('设备信息', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (detail.isNotEmpty) _buildInfoRow(theme, '地址', detail),
                  if (brand.isNotEmpty) _buildInfoRow(theme, '品牌', brand),
                  if (model.isNotEmpty) _buildInfoRow(theme, '型号', model),
                  _buildInfoRow(theme, '设备ID', widget.deviceId),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _payTypeLabel(int type) {
    return switch (type) {
      21 => '按量计费',
      91 => '按次计费',
      _ => '类型$type',
    };
  }

  Widget _buildStat(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
