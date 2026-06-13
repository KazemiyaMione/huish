import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'score_screen.dart';
import 'bill_screen.dart';
import 'device_settings_screen.dart';
import 'add_device_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _themeColors = [
    Color(0xFF1565C0), // Blue
    Color(0xFF00897B), // Teal
    Color(0xFF2E7D32), // Green
    Color(0xFF6A1B9A), // Purple
    Color(0xFFE65100), // Orange
    Color(0xFFC62828), // Red
  ];
  Map<String, dynamic>? _accountData;
  Map<String, dynamic>? _scoreInfo;
  bool _loadingAccount = true;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final api = context.read<AuthProvider>().api;
    // Load cached master instantly
    final cached = await api.loadCachedMaster();
    if (cached != null && mounted) {
      setState(() {
        _accountData = cached['account'] as Map<String, dynamic>?;
        _loadingAccount = false;
      });
    }
    try {
      final results = await Future.wait([
        api.getMaster(),
        api.getMissionList(),
      ]);
      if (!mounted) return;
      if (results[0].isSuccess) {
        _accountData = results[0].dataMap?['account'] as Map<String, dynamic>?;
      }
      if (results[1].isSuccess) {
        _scoreInfo = results[1].dataMap?['accScoreRsp'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountCard(context),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          const SizedBox(height: 16),
          _buildSettings(context, settings),
          const SizedBox(height: 16),
          _buildAbout(context),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingAccount) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final account = _accountData;
    final name = account?['name'] as String? ?? '未登录';
    final pn = account?['pn'] as String? ?? '';
    final img = account?['img'] as String?; // field is "img" not "avt"
    final score = _scoreInfo?['score'] as String? ?? '0';
    final totalScore = _scoreInfo?['totalScore'] as String? ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary,
                  backgroundImage: img != null && img.isNotEmpty ? NetworkImage(img) : null,
                  child: img == null || img.isEmpty ? const Icon(Icons.person, size: 32, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (pn.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(pn, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('积分', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      score,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
            if (totalScore != '0') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('可用积分', score),
                  _buildStat('累计获得', totalScore),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text('添加设备'),
            subtitle: const Text('扫码或输入设备码绑定饮水机'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
              );
              if (added == true && mounted) _loadAccount();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.stars, color: Colors.orange),
            title: const Text('积分中心'),
            subtitle: const Text('赚积分、查看积分明细'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScoreScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.teal),
            title: const Text('消费记录'),
            subtitle: const Text('查看饮水消费账单'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BillScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('设备管理'),
            subtitle: const Text('设备状态查询、指令发送、模式选择'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录'),
            subtitle: const Text('清除登录信息并返回登录页'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                final nav = Navigator.of(context);
                await context.read<AuthProvider>().logout();
                nav.pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context, SettingsProvider settings) {
    final useScore = (_accountData?['useScore'] as int?) == 1;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.palette, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                const Text('主题色', style: TextStyle(fontSize: 15)),
                const Spacer(),
                ..._themeColors.map((c) => GestureDetector(
                      onTap: () => settings.setSeedColor(c),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: settings.seedColor.toARGB32() == c.toARGB32()
                                ? Colors.black
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            if (settings.seedColor.toARGB32() == c.toARGB32())
                              BoxShadow(color: c.withAlpha(100), blurRadius: 6, spreadRadius: 1),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(
              settings.isDark ? Icons.dark_mode : Icons.light_mode,
              color: settings.isDark ? Colors.blueGrey : Colors.orange,
            ),
            title: const Text('深色模式'),
            subtitle: Text(settings.isDark ? '已开启深色模式' : '已关闭深色模式'),
            value: settings.isDark,
            onChanged: (_) => settings.toggleTheme(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(
              useScore ? Icons.savings : Icons.savings_outlined,
              color: useScore ? Colors.orange : Colors.grey,
            ),
            title: const Text('积分抵扣'),
            subtitle: Text(useScore ? '已开启，消费时自动使用积分抵扣' : '已关闭'),
            value: useScore,
            onChanged: (_) => _toggleUseScore(),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUseScore() async {
    final current = (_accountData?['useScore'] as int?) == 1;
    final api = context.read<AuthProvider>().api;
    try {
      final resp = await api.setUseScore(!current);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _accountData = {
            ...?_accountData,
            'useScore': current ? 0 : 1,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(current ? '积分抵扣已关闭' : '积分抵扣已开启'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置失败 (code: ${resp.code})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，请重试')),
        );
      }
    }
  }

  Widget _buildAbout(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('关于', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildAboutRow(context, Icons.info_outline, '版本', '1.5.0'),
            const SizedBox(height: 12),
            _buildAboutRow(context, Icons.water_drop_outlined, '应用名称', '云水 · 直饮水'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {},
              child: _buildAboutRow(
                context,
                Icons.code,
                '源码仓库',
                'https://github.com/KazemiyaMione/huish',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        const Spacer(),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
