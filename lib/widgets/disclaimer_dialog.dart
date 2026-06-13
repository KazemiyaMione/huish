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

  static const _sections = [
    _Section(
      '1. 非官方性质',
      '本软件与"慧生活798"及其关联公司、饮水设备所有权方、运营方不存在任何隶属、合作、背书或认证关系。'
          '所有设备信息、用水数据等均通过公开或合法授权接口获取，本软件不对数据的实时性、准确性、完整性做任何担保。',
    ),
    _Section(
      '2. 风险自担',
      '您已知晓并自愿承担使用本软件的一切风险，包括但不限于：\n'
          '• 因软件缺陷、兼容性问题或第三方服务变更导致的用水失败、数据丢失、设备异常；\n'
          '• 因网络传输、服务器故障造成的服务中断或延迟；\n'
          '• 您误操作（如错误绑定设备、提交异常指令）引发的后果。',
    ),
    _Section(
      '3. 责任限制',
      '在适用法律允许的最大范围内，开发者及贡献者不对任何直接、间接、偶然、特殊或惩罚性损失承担责任，'
          '包括但不限于：利润损失、数据丢失、设备损坏、人身伤害或任何第三方索赔。'
          '即使开发者已被告知可能发生此类损害，本限制依然适用。',
    ),
    _Section(
      '4. 合法使用承诺',
      '您承诺仅将本软件用于合法目的，遵守中华人民共和国相关法律法规，不得利用本软件：\n'
          '• 破解、干扰、破坏饮水设备的正常运营机制；\n'
          '• 窃取他人用水凭证或隐私信息；\n'
          '• 进行商业性批量获取、转售用水数据；\n'
          '• 其他任何违法或侵犯第三方权益的行为。',
    ),
    _Section(
      '5. 开源与禁止商用',
      '本软件基于 MIT 协议开源发布，源代码仅供学习参考。严禁将本软件或其任何衍生版本用于商业目的，'
          '包括但不限于：内嵌广告、收费分发、作为商业服务的一部分。任何商业使用行为均需获得开发者单独书面授权。',
    ),
    _Section(
      '6. 设备与运营归属',
      '所有实际饮水设备的所有权、运营权、维护责任均归属设备提供方（学校、物业、运营公司等）。'
          '本软件不控制、不管理任何硬件设备，如因设备本身质量、维护不当或运营方政策变更导致的问题，请直接联系设备运营方解决。',
    ),
    _Section(
      '7. 保留权利与修改',
      '开发者保留随时修改、更新本免责声明的权利。修改后的声明将在新版本软件中公布，不另行单独通知。'
          '您若继续使用更新后的软件，视为接受修改后的条款。',
    ),
    _Section(
      '8. 法律适用与管辖',
      '本声明的解释、效力及争议解决适用中华人民共和国法律。因本软件引起的任何争议，'
          '应优先通过友好协商解决；协商不成的，由开发者所在地有管辖权的人民法院管辖。',
    ),
  ];

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
                '本软件（云水 · 直饮水，以下简称"本软件"）为第三方独立开发的非官方客户端，仅供个人学习、研究与技术交流使用。\n'
                '使用本软件即表示您已阅读、理解并同意本免责声明的全部条款。',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              ..._sections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(s.body, style: const TextStyle(fontSize: 13, height: 1.5)),
                      ],
                    ),
                  )),
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

/// Single section of the disclaimer.
class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}
