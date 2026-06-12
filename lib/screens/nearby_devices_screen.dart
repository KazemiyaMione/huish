import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class NearbyDevicesScreen extends StatefulWidget {
  const NearbyDevicesScreen({super.key});

  @override
  State<NearbyDevicesScreen> createState() => _NearbyDevicesScreenState();
}

class _NearbyDevicesScreenState extends State<NearbyDevicesScreen> {
  final _lngCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  List<dynamic>? _devices;
  bool _loading = true;
  String? _error;
  final Set<String> _favoritingIds = {};

  @override
  void initState() {
    super.initState();
    _initCoords();
  }

  @override
  void dispose() {
    _lngCtrl.dispose();
    _latCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCoords() async {
    final api = context.read<AuthProvider>().api;
    final cached = await api.loadCachedMaster();
    if (cached != null) {
      final favos = cached['favos'] as List<dynamic>?;
      if (favos != null && favos.isNotEmpty) {
        final first = favos.first as Map<String, dynamic>?;
        final addr = first?['addr'] as Map<String, dynamic>?;
        final lng = addr?['lng'];
        final lat = addr?['lat'];
        if (lng != null && lat != null) {
          _lngCtrl.text = lng.toString();
          _latCtrl.text = lat.toString();
        }
      }
    }
    _loadNearby();
  }

  Future<void> _loadNearby() async {
    final api = context.read<AuthProvider>().api;
    final eid = api.eid;
    if (eid == null) {
      setState(() {
        _error = '未获取到企业信息，请先登录';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final lng = double.tryParse(_lngCtrl.text);
    final lat = double.tryParse(_latCtrl.text);

    try {
      final resp = await api.getNearbyDevices(eid: eid, dtype: 8, lng: lng, lat: lat);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _devices = resp.dataList ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = '加载失败 (code: ${resp.code})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '网络异常，请检查网络后重试';
          _loading = false;
        });
      }
    }
  }

  Future<void> _favorite(String deviceId) async {
    final api = context.read<AuthProvider>().api;
    setState(() => _favoritingIds.add(deviceId));
    try {
      final resp = await api.favoriteDevice(deviceId);
      if (!mounted) return;
      if (resp.isSuccess) {
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
    if (mounted) setState(() => _favoritingIds.remove(deviceId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近设备'),
      ),
      body: Column(
        children: [
          _buildCoordBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCoordBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '经度',
                hintText: 'lng',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _latCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '纬度',
                hintText: 'lat',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _loadNearby,
            icon: const Icon(Icons.search),
          ),
        ],
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
            ElevatedButton(onPressed: _loadNearby, child: const Text('重试')),
          ],
        ),
      );
    }

    final devices = _devices ?? [];

    if (devices.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('附近暂无设备', style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearby,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        itemBuilder: (_, i) {
          final d = devices[i] as Map<String, dynamic>;
          final id = d['id'] as String? ?? '';
          final name = d['name'] as String? ?? '未知设备';
          final addr = d['addr'] as Map<String, dynamic>?;
          final detail = addr?['detail'] as String? ?? '';
          final city = addr?['city'] as String? ?? '';
          final bm = d['bm'] as Map<String, dynamic>?;
          final brand = bm?['brand'] as String? ?? '';
          final model = bm?['model'] as String? ?? '';
          final gene = d['gene'] as Map<String, dynamic>?;
          final price = gene?['price'] as num? ?? 0;
          final favoriting = _favoritingIds.contains(id);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const Icon(Icons.water_drop_outlined, color: Colors.blue, size: 32),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '$city · $detail',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _infoRow('设备ID', id),
                if (brand.isNotEmpty) _infoRow('品牌', brand),
                if (model.isNotEmpty) _infoRow('型号', model),
                if (price > 0) _infoRow('单价', '${(price as double) / 100} 元'),
                _infoRow('位置', '$city $detail'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: favoriting ? null : () => _favorite(id),
                    icon: favoriting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.favorite_border),
                    label: Text(favoriting ? '收藏中...' : '收藏设备'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
