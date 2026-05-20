import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _accountData;
  bool _loadingAccount = true;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final api = context.read<AuthProvider>().api;
    final cached = await api.loadCachedMaster();
    if (cached != null && mounted) {
      setState(() {
        _accountData = cached['account'] as Map<String, dynamic>?;
        _loadingAccount = false;
      });
    }
    try {
      final resp = await api.getMaster();
      if (resp.isSuccess && mounted) {
        setState(() {
          _accountData = resp.data?['account'] as Map<String, dynamic>?;
          _loadingAccount = false;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingAccount = false);
    }
  }

  Future<void> _showAddDeviceDialog(BuildContext context) async {
    final api = context.read<AuthProvider>().api;
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加设备'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '设备码',
            hintText: '请输入设备码',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('绑定'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final did = ctrl.text.trim();
    if (did.isEmpty) return;
    try {
      final resp = await api.getDeviceQr(did);
      if (!mounted) return;
      if (resp.isSuccess) {
        messenger.showSnackBar(
          const SnackBar(content: Text('设备添加成功'), backgroundColor: Colors.green),
        );
      } else if (resp.code == 400 || resp.code == 409) {
        messenger.showSnackBar(
          const SnackBar(content: Text('设备已在列表中或已绑定'), backgroundColor: Colors.orange),
        );
      } else {
        final msg = resp.data?['msg'] as String? ?? '绑定失败';
        messenger.showSnackBar(
          SnackBar(content: Text('$msg (code: ${resp.code})')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('网络异常，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor: theme.colorScheme.inversePrimary,
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
    final useScore = account?['useScore'] as num? ?? 0;

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
                  child: const Icon(Icons.person, size: 32, color: Colors.white),
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
                      '$useScore',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text('添加设备'),
            subtitle: const Text('输入设备码绑定饮水机'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAddDeviceDialog(context),
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
    return Card(
      child: Column(
        children: [
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
        ],
      ),
    );
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
            _buildAboutRow(context, Icons.info_outline, '版本', '1.1.3'),
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
