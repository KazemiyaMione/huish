import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  List<dynamic>? _bills;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await api.getBillList();
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _bills = resp.data as List<dynamic>? ?? [];
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

  String _billTypeLabel(int type) {
    return switch (type) {
      21 => '按量消费',
      91 => '按次消费',
      _ => '消费',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消费记录'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: _buildBody(),
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
            ElevatedButton(onPressed: _loadBills, child: const Text('重试')),
          ],
        ),
      );
    }

    final bills = _bills ?? [];

    if (bills.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('暂无消费记录', style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bills.length,
        itemBuilder: (_, i) {
          final b = bills[i] as Map<String, dynamic>;
          final payment = (b['payment'] as num?)?.toDouble() ?? 0;
          final ctime = b['ctime'] as int?;
          final timeStr = ctime != null
              ? DateTime.fromMillisecondsSinceEpoch(ctime).toString().substring(0, 16)
              : '';
          final type = b['type'] as int? ?? 0;
          final status = b['status'] as int? ?? 0;
          final devName = (b['dev'] as Map<String, dynamic>?)?['name'] as String? ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[50],
                child: const Icon(Icons.water_drop, color: Colors.blue),
              ),
              title: Text('${_billTypeLabel(type)} ¥${payment.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [timeStr, devName].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 3 ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status == 3 ? '已完成' : '进行中',
                  style: TextStyle(
                    fontSize: 11,
                    color: status == 3 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
