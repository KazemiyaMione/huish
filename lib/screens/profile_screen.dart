import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'qr_scan_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserCard(context, auth),
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

  Widget _buildUserCard(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
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
                    auth.isLoggedIn ? '已登录' : '未登录',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.api.uid ?? '用户ID',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (auth.isLoggedIn)
              Icon(Icons.check_circle, color: Colors.green[400], size: 24),
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
            leading: const Icon(Icons.qr_code_scanner, color: Colors.blue),
            title: const Text('扫码添加设备'),
            subtitle: const Text('扫描设备二维码进行绑定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const QrScanScreen()),
              );
              if (added == true && context.mounted) {
                // Pop to main shell which will refresh home
              }
            },
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
            _buildAboutRow(context, Icons.info_outline, '版本', '1.0.0'),
            const SizedBox(height: 12),
            _buildAboutRow(context, Icons.water_drop_outlined, '应用名称', '云水 · 直饮水'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                // Copy repo URL to clipboard or open
              },
              child: _buildAboutRow(
                context,
                Icons.code,
                '源码仓库',
                'github.com/YOUR_USERNAME/cloudora',
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
