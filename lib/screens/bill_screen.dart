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
  int? _statusFilter; // null=全部, 1=未付款, 2=待确认, 3=已付款, 4=付款失败, 9=已取消

  static const _statusFilters = <int?, _FilterInfo>{
    null: _FilterInfo('全部', null),
    1: _FilterInfo('未付款', Colors.orange),
    2: _FilterInfo('待确认', Colors.blue),
    3: _FilterInfo('已付款', Colors.green),
    4: _FilterInfo('失败', Colors.red),
    9: _FilterInfo('已取消', Colors.grey),
  };

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
      final resp = await api.getBillList(status: _statusFilter);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _bills = resp.dataList ?? [];
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

  Future<void> _showBillDetail(String billId) async {
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.getBillDetail(billId);
      if (!mounted || !resp.isSuccess) return;
      final bill = resp.dataMap?['bill'] as Map<String, dynamic>?;
      if (bill == null || !mounted) return;

      final payment = (bill['payment'] as num?)?.toDouble() ?? 0;
      final ctime = bill['ctime'] as int?;
      final timeStr = ctime != null
          ? DateTime.fromMillisecondsSinceEpoch(ctime).toString().substring(0, 19)
          : '';
      final type = bill['type'] as int? ?? 0;
      final status = bill['status'] as int? ?? 0;
      final msg = bill['msg'] as String? ?? '';
      final dev = bill['dev'] as Map<String, dynamic>?;
      final devName = dev?['name'] as String? ?? '';
      final payee = bill['payee'] as String? ?? '';
      final discount = (bill['discount'] as num?)?.toDouble() ?? 0;
      final tag = bill['tag'] as String? ?? '';

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('账单详情'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('金额', '¥${payment.toStringAsFixed(2)}'),
              _detailRow('类型', _billTypeLabel(type)),
              if (discount > 0) _detailRow('折扣', '¥${discount.toStringAsFixed(2)}'),
              if (msg.isNotEmpty) _detailRow('描述', msg),
              if (devName.isNotEmpty) _detailRow('设备', devName),
              if (payee.isNotEmpty) _detailRow('收款方', payee),
              if (tag.isNotEmpty) _detailRow('交易号', tag),
              _detailRow('时间', timeStr),
              _detailRow('状态', _statusLabel(status)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          ],
        ),
      );
    } catch (_) {}
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _billTypeLabel(int type) {
    return switch (type) {
      21 => '按量消费',
      91 => '按次消费',
      _ => '消费',
    };
  }

  String _statusLabel(int status) {
    return switch (status) {
      1 => '未付款',
      2 => '待确认',
      3 => '已付款',
      4 => '付款失败',
      9 => '已取消',
      _ => '未知',
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
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _statusFilters.entries.map((e) {
          final selected = _statusFilter == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value.label),
              selected: selected,
              onSelected: (_) {
                setState(() => _statusFilter = e.key);
                _loadBills();
              },
              selectedColor: e.value.color?.withValues(alpha: 0.3),
              checkmarkColor: e.value.color,
            ),
          );
        }).toList(),
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
            ElevatedButton(onPressed: _loadBills, child: const Text('重试')),
          ],
        ),
      );
    }

    final bills = _bills ?? [];

    if (bills.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_statusFilter != null ? '暂无该状态账单' : '暂无消费记录',
              style: const TextStyle(color: Colors.grey, fontSize: 16))),
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
          final msg = b['msg'] as String? ?? '饮水消费';

          final bid = b['id'] as String? ?? '';
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
                '$msg\n$timeStr',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status)?.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 11, color: _statusColor(status)),
                ),
              ),
              onTap: () => _showBillDetail(bid),
            ),
          );
        },
      ),
    );
  }

  Color? _statusColor(int status) {
    return switch (status) {
      1 => Colors.orange,
      2 => Colors.blue,
      3 => Colors.green,
      4 => Colors.red,
      9 => Colors.grey,
      _ => Colors.grey,
    };
  }
}

class _FilterInfo {
  final String label;
  final Color? color;
  const _FilterInfo(this.label, this.color);
}
