import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String? _currentEid;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final api = context.read<AuthProvider>().api;
    final eid = _currentEid ?? api.eid;
    if (eid == null) {
      setState(() {
        _error = '未获取到企业信息';
        _loading = false;
      });
      return;
    }
    _currentEid = eid;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await api.getWalletOwner(eid);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _data = resp.dataMap;
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
          _error = '网络异常，请重试';
          _loading = false;
        });
      }
    }
  }

  Future<void> _signAlipay() async {
    final api = context.read<AuthProvider>().api;
    final eid = _currentEid;
    if (eid == null) return;

    // Check signing status
    try {
      final check = await api.checkPga(eid);
      if (!mounted) return;
      if (check.code == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已签约，无需重复操作'), backgroundColor: Colors.green),
        );
        return;
      }
    } catch (_) {}

    // Get sign
    try {
      final signResp = await api.getPgaSign(20); // 20 = Alipay
      if (!mounted) return;
      if (!signResp.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取签约信息失败 (code: ${signResp.code})')),
        );
        return;
      }
      final sign = signResp.dataMap?['sign'] as String?;
      if (sign == null || sign.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('签约参数为空')),
        );
        return;
      }

      final decoded = Uri.decodeComponent(sign);
      // Alipay deeplink: wrap the full SDK param string as orderStr
      final encoded = Uri.encodeComponent(decoded);

      // Try multiple deeplink formats
      final urls = [
        // Primary: startApp with orderStr (agreement signing appId=20000116)
        Uri.parse('alipays://platformapi/startApp?appId=20000116&orderStr=$encoded'),
        // Fallback: startapp with direct params
        Uri.parse('alipays://platformapi/startapp?$decoded'),
        // Fallback: legacy scheme
        Uri.parse('alipay://platformapi/startApp?appId=20000116&orderStr=$encoded'),
      ];

      bool launched = false;
      for (final url in urls) {
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
          launched = true;
          break;
        }
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未安装支付宝 App，请先安装')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('钱包')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadWallet, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final data = _data;
    if (data == null) return const Center(child: Text('无数据'));

    final aw = data['aw'] as Map<String, dynamic>?;
    final eps = (data['eps'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final nears = (data['nears'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final olCash = (aw?['olCash'] as num?)?.toDouble() ?? 0;
    final olGift = (aw?['olGift'] as num?)?.toDouble() ?? 0;
    final total = (aw?['total'] as num?)?.toDouble() ?? 0;
    final epName = aw?['ep']?['name'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(epName,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer.withAlpha(180))),
              const SizedBox(height: 8),
              Text('¥${total.toStringAsFixed(2)}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  )),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip(theme, '现金 ¥${olCash.toStringAsFixed(2)}'),
                  const SizedBox(width: 12),
                  _chip(theme, '赠送 ¥${olGift.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Sign button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _signAlipay,
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('支付宝代扣签约'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('签约后可线上充值', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),

        // Wallet list
        if (eps.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('全部钱包', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...eps.map((w) {
            final name = w['name'] as String? ?? '';
            final wTotal = (w['total'] as num?)?.toDouble() ?? 0;
            final wCash = (w['olCash'] as num?)?.toDouble() ?? 0;
            final weid = w['ep']?['id'] as String? ?? '';
            final isActive = _currentEid == weid;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isActive ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
                  color: isActive ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('现金 ¥${wCash.toStringAsFixed(2)}'),
                trailing: Text('¥${wTotal.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                        color: Theme.of(context).colorScheme.primary)),
                onTap: () {
                  setState(() => _currentEid = weid);
                  _loadWallet();
                },
              ),
            );
          }),
        ],

        // Nearby merchants
        if (nears.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('附近商户', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...nears.map((n) {
            final name = n['name'] as String? ?? '';
            final nid = n['id'] as String? ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.store),
                title: Text(name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() => _currentEid = nid);
                  _loadWallet();
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _chip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer.withAlpha(180))),
    );
  }
}
