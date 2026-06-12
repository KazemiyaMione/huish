import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'device_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _masterData;
  bool _loading = true;
  String? _error;
  final Set<String> _runningDeviceIds = {};

  @override
  void initState() {
    super.initState();
    _loadCachedThenFresh();
  }

  Future<void> _loadCachedThenFresh() async {
    final api = context.read<AuthProvider>().api;
    // Show cached data instantly
    final cached = await api.loadCachedMaster();
    if (cached != null && mounted) {
      setState(() {
        _masterData = cached;
        _loading = false;
      });
    }
    // Then fetch fresh data
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    final api = context.read<AuthProvider>().api;
    final hasData = _masterData != null;
    // Only show full loading when no cached data
    if (!hasData) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final resp = await api.getMaster();
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _masterData = resp.data;
          _loading = false;
          _error = null;
        });
      } else {
        if (resp.code == 401 || resp.code == 403) {
          await context.read<AuthProvider>().logout();
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
        // Only show error if we have no data at all
        if (!hasData) {
          setState(() {
            _loading = false;
            _error = '加载失败 (code: ${resp.code})';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!hasData) {
        setState(() {
          _loading = false;
          _error = '网络异常，请检查网络后重试';
        });
      }
    }
  }

  Future<void> _openDevice(String id, String name) async {
    final result = await Navigator.of(context).push<DeviceResult>(
      MaterialPageRoute(
        builder: (_) => DeviceScreen(
          deviceId: id,
          deviceName: name,
          initiallyRunning: _runningDeviceIds.contains(id),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        if (result.running) {
          _runningDeviceIds.add(id);
        } else {
          _runningDeviceIds.remove(id);
        }
      });
      _loadMaster();
    }
  }

  Future<void> _unfavoriteDevice(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除设备'),
        content: Text('确定从列表中移除「$name」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final resp = await context.read<AuthProvider>().api.favoriteDevice(id, remove: true);
      if (!mounted) return;
      if (resp.isSuccess) {
        _runningDeviceIds.remove(id);
        _loadMaster();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已移除'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败 (code: ${resp.code})')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云水 · 直饮水'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final favos = _masterData?['favos'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadMaster,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.orange[800]))),
                    TextButton(onPressed: _loadMaster, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('我的设备', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (_runningDeviceIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_runningDeviceIds.length}台运行中',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (favos.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text('暂无设备', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('前往「我的」页面输入设备码添加', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadMaster,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新试试'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...favos.map((f) => _buildDeviceCard(f as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> favo) {
    final id = favo['id'] as String? ?? '';
    final name = favo['name'] as String? ?? '未知设备';
    final addr = favo['addr'] as Map<String, dynamic>?;
    final detail = addr?['detail'] as String? ?? '';
    final city = addr?['city'] as String? ?? '';
    final running = _runningDeviceIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          running ? Icons.water_drop : Icons.water_drop_outlined,
          size: 40,
          color: running ? Colors.blue : Colors.grey,
        ),
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (running)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('运行中', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
          ],
        ),
        subtitle: Text('$city · $detail', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        onTap: () => _openDevice(id, name),
        onLongPress: () => _unfavoriteDevice(id, name),
      ),
    );
  }
}
