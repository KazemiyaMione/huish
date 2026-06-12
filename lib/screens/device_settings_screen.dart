import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'nearby_devices_screen.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  List<dynamic>? _devices;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final api = context.read<AuthProvider>().api;
    // Load cached first
    final cached = await api.loadCachedMaster();
    if (cached != null && mounted) {
      setState(() {
        _devices = cached['favos'] as List<dynamic>? ?? [];
        _loading = false;
      });
    }
    try {
      final resp = await api.getMaster();
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _devices = resp.dataMap?['favos'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCommand(String deviceId, int status) async {
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.sendDeviceCommand(deviceId: deviceId, status: status);
      if (!mounted) return;
      if (resp.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 1 ? '设备已开启' : '设备已关闭'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('指令失败 (code: ${resp.code})')),
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

  Future<void> _toggleFavorite(String deviceId, String name, bool isFav) async {
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.favoriteDevice(deviceId, remove: isFav);
      if (!mounted) return;
      if (resp.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFav ? '已取消收藏' : '已收藏'), backgroundColor: Colors.green),
        );
        _loadDevices();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: '附近设备',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NearbyDevicesScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildDeviceList(),
    );
  }

  Widget _buildDeviceList() {
    final devices = _devices ?? [];

    if (devices.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('暂无设备', style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        itemBuilder: (_, i) {
          final d = devices[i] as Map<String, dynamic>;
          final id = d['id'] as String? ?? '';
          final name = d['name'] as String? ?? '未知设备';
          final gene = d['gene'] as Map<String, dynamic>?;
          final status = gene?['status'] as int? ?? 0;
          final running = status == 1;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: Icon(
                running ? Icons.water_drop : Icons.water_drop_outlined,
                color: running ? Colors.blue : Colors.grey,
                size: 32,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                running ? '运行中 · status=$status' : '空闲 · status=$status',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              children: [
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.play_arrow, color: Colors.green),
                  title: const Text('发送开机指令'),
                  subtitle: const Text('gene.status=1, mode=100'),
                  onTap: () => _sendCommand(id, 1),
                ),
                ListTile(
                  leading: const Icon(Icons.stop, color: Colors.red),
                  title: const Text('发送关机指令'),
                  subtitle: const Text('gene.status=0, mode=100'),
                  onTap: () => _sendCommand(id, 0),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('取消收藏'),
                  onTap: () => _toggleFavorite(id, name, true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
