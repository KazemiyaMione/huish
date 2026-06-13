import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisclaimerDialog extends StatefulWidget {
  const DisclaimerDialog({super.key});

  static const _keySeen = 'disclaimer_seen';

  /// Returns true if the user has already accepted the disclaimer.
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeen) ?? false;
  }

  /// Show the disclaimer if not yet accepted. Returns after user confirms.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (await hasAccepted()) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DisclaimerDialog(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeen, true);
  }

  @override
  State<DisclaimerDialog> createState() => _DisclaimerDialogState();
}

class _DisclaimerDialogState extends State<DisclaimerDialog> {
  int _remaining = 10;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    for (var i = _remaining; i >= 0; i--) {
      if (!mounted) return;
      setState(() => _remaining = i);
      if (i > 0) await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('免责声明'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '本软件（云水 · 直饮水）仅供学习和研究用途。\n\n'
                '使用本软件即表示您同意：\n'
                '• 本软件为非官方客户端，与慧生活798无任何关联\n'
                '• 您应自行承担使用本软件的一切风险和责任\n'
                '• 开发者不对因使用本软件造成的任何损失负责\n'
                '• 请遵守相关法律法规，不得用于非法用途\n'
                '• 本软件开源免费，禁止用于商业目的\n\n'
                '饮水设备的所有权及运营归属设备提供方。',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          Text(
            _remaining > 0 ? '请阅读 ${_remaining}s' : '已阅读',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _remaining > 0 ? null : () => Navigator.of(context).pop(),
            child: Text(_remaining > 0 ? '确认 ($_remaining)' : '确认'),
          ),
        ],
      ),
    );
  }
}
