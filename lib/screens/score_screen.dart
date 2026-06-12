import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/sign_utils.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  Map<String, dynamic>? _missionData;
  List<dynamic>? _scoreHistory;
  bool _loading = true;
  String? _error;
  final Set<String> _claimingTasks = {};
  bool _autoClaiming = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.getMissionList(),
        api.getScoreList(),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].isSuccess) _missionData = results[0].dataMap;
        if (results[1].isSuccess) {
          _scoreHistory = results[1].dataList;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _claimScore(Map<String, dynamic> mission) async {
    final refId = mission['refId'] as String?;
    final score = mission['score'] as int?;
    if (refId == null || score == null) return;

    final api = context.read<AuthProvider>().api;
    final token = api.token;
    final uid = api.uid;
    if (token == null || uid == null) return;

    setState(() => _claimingTasks.add(refId));

    // Record local time before the request
    final localTs = DateTime.now().millisecondsSinceEpoch;
    // Fetch mission list to get server time for sign
    try {
      final mlResp = await api.getMissionList();
      if (!mounted) return;
      final serverTs = mlResp.time ?? localTs;

      final sign = SignUtils.generateScoreSign(
        adId: refId,
        token: token,
        uid: uid,
        localTs: localTs,
        serverTs: serverTs,
      );

      final resp = await api.sendScore(adId: refId, score: score, sign: sign);
      if (!mounted) return;
      if (resp.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('领取成功 +$score 积分'), backgroundColor: Colors.green),
        );
        _loadData();
      } else if (resp.code == -98) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作过快，请稍后再试'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp.dataMap?['msg'] as String? ?? '领取失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，请重试')),
        );
      }
    }
    if (mounted) setState(() => _claimingTasks.remove(refId));
  }

  Future<void> _claimAll() async {
    final missions = (_missionData?['missions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .where((m) {
              final limit = m['limit'] as int? ?? 0;
              final cnt = m['cnt'] as int? ?? 0;
              final remaining = limit == -4 ? 999 : (limit - cnt).clamp(0, 999);
              return remaining > 0;
            })
            .toList() ??
        [];

    if (missions.isEmpty) return;

    setState(() => _autoClaiming = true);
    int claimed = 0;
    for (final m in missions) {
      await _claimScore(m);
      claimed++;
      // Small delay between claims to avoid rate limiting
      if (claimed < missions.length) await Future.delayed(const Duration(seconds: 2));
    }
    if (mounted) {
      setState(() => _autoClaiming = false);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已领取 $claimed 个任务'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreInfo = _missionData?['accScoreRsp'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分中心'),
        backgroundColor: theme.colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '赚积分'),
            Tab(text: '积分明细'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('重试')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (scoreInfo != null) _buildScoreHeader(scoreInfo),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildMissionTab(),
                          _buildHistoryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildScoreHeader(Map<String, dynamic> info) {
    final score = info['score'] as String? ?? '0';
    final totalScore = info['totalScore'] as String? ?? '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        ),
      ),
      child: Column(
        children: [
          const Text('可用积分', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(score, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('累计获得: $totalScore', style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMissionTab() {
    final missions = (_missionData?['missions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ??
        [];

    final claimable = missions.any((m) {
      final limit = m['limit'] as int? ?? 0;
      final cnt = m['cnt'] as int? ?? 0;
      final remaining = limit == -4 ? 999 : (limit - cnt).clamp(0, 999);
      return remaining > 0;
    });

    if (missions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('暂无可用任务', style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: missions.length + (claimable ? 1 : 0),
        itemBuilder: (_, i) {
          if (claimable && i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _autoClaiming ? null : _claimAll,
                  icon: _autoClaiming
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.stars),
                  label: Text(_autoClaiming ? '领取中...' : '一键领取'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            );
          }
          final idx = claimable ? i - 1 : i;
          final m = missions[idx];
          final refId = m['refId'] as String? ?? '';
          final name = m['name'] as String? ?? '未知任务';
          final desc = m['desc'] as String? ?? '';
          final score = m['score'] as int? ?? 0;
          final limit = m['limit'] as int? ?? 0;
          final cnt = m['cnt'] as int? ?? 0;
          final claiming = _claimingTasks.contains(refId);
          final remaining = limit == -4 ? 999 : (limit - cnt).clamp(0, 999);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[50],
                child: Text('+$score', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('$desc\n剩余 $remaining 次', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              isThreeLine: true,
              trailing: claiming
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : remaining > 0
                      ? TextButton(
                          onPressed: () => _claimScore(m),
                          child: const Text('领取'),
                        )
                      : const Text('已领完', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    final items = _scoreHistory ?? [];

    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('暂无积分记录', style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i] as Map<String, dynamic>;
          final title = item['name'] as String? ?? item['msg'] as String? ?? '积分变动';
          final score = item['score'] as num? ?? 0;
          final ctime = item['ctime'] as int?;
          final timeStr = ctime != null
              ? DateTime.fromMillisecondsSinceEpoch(ctime).toString().substring(0, 16)
              : '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                score > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: score > 0 ? Colors.green : Colors.red,
              ),
              title: Text(title),
              subtitle: Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: Text(
                '${score > 0 ? '+' : ''}$score',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: score > 0 ? Colors.green : Colors.red,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
