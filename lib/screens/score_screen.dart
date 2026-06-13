import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/sign_utils.dart';
import '../widgets/score_header.dart';

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
  int? _srcFilter;
  double _delaySeconds = 10; // 可自定义间隔秒数
  int _localTs = 0;
  int _serverTs = 0;

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
      _localTs = DateTime.now().millisecondsSinceEpoch;
      final results = await Future.wait([
        api.getMissionList(),
        api.getScoreList(src: _srcFilter),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].isSuccess) {
          _missionData = results[0].dataMap;
          _serverTs = results[0].time ?? _localTs;
        }
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

  /// Get the exhausted refIds from accScoreRsp.limits (server-authoritative).
  Set<String> _exhaustedRefIds() {
    final limits = _missionData?['accScoreRsp']?['limits'] as List<dynamic>? ?? [];
    final exhausted = <String>{};
    for (final l in limits) {
      final m = l as Map<String, dynamic>;
      final refId = m['refId'] as String?;
      final limitVal = m['limit'] as int? ?? 0;
      if (refId != null && limitVal <= 0) exhausted.add(refId);
    }
    return exhausted;
  }

  int _remainingFromLimits(String refId) {
    final limits = _missionData?['accScoreRsp']?['limits'] as List<dynamic>? ?? [];
    for (final l in limits) {
      final m = l as Map<String, dynamic>;
      if (m['refId'] == refId) {
        return m['limit'] as int? ?? 0;
      }
    }
    // Not in limits list yet — check mission's own limit/cnt
    return 999; // fallback
  }

  Future<bool> _claimScore(Map<String, dynamic> mission, {bool silent = false}) async {
    final refId = mission['refId'] as String?;
    final score = mission['score'] as int?;
    if (refId == null || score == null || score <= 0) return false;

    final api = context.read<AuthProvider>().api;
    final token = api.token;
    final uid = api.uid;
    if (token == null || uid == null) return false;

    if (!silent) setState(() => _claimingTasks.add(refId));

    try {
      // Retry up to 3 times for -98 rate limiting
      for (int attempt = 0; attempt < 3; attempt++) {
        final sign = SignUtils.generateScoreSign(
          adId: refId,
          token: token,
          uid: uid,
          localTs: _localTs,
          serverTs: _serverTs,
        );

        final resp = await api.sendScore(adId: refId, score: score, sign: sign);
        if (!mounted) return false;

        if (resp.isSuccess) {
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('领取成功 +$score 积分'), backgroundColor: Colors.green),
            );
          }
          return true;
        } else if (resp.code == -98 && attempt < 2) {
          final wait = 8 + attempt * 5; // 8s → 13s → 18s
          await Future.delayed(Duration(seconds: wait));
          continue;
        } else {
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(resp.dataMap?['msg'] as String? ?? '领取失败 (${resp.code})')),
            );
          }
          return false;
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，请重试')),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _claimingTasks.remove(refId));
    }
    return false;
  }

  Future<void> _claimAll() async {
    final missions = (_missionData?['missions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .where((m) {
              final refId = m['refId'] as String? ?? '';
              final score = m['score'] as int? ?? 0;
              return score > 0 && !_exhaustedRefIds().contains(refId);
            })
            .toList() ??
        [];

    if (missions.isEmpty) return;

    setState(() => _autoClaiming = true);
    final api = context.read<AuthProvider>().api;
    final messenger = ScaffoldMessenger.of(context);

    // Record score before claiming
    final beforeScore = _missionData?['accScoreRsp']?['score'] as String? ?? '0';

    int claimed = 0;
    for (int i = 0; i < missions.length; i++) {
      if (!mounted) break;
      final m = missions[i];

      // Check limits again before each claim (may have been exhausted mid-batch)
      final refId = m['refId'] as String? ?? '';
      if (_exhaustedRefIds().contains(refId)) continue;

      final ok = await _claimScore(m, silent: true);
      if (ok) claimed++;

      // Refresh mission list to get updated limits
      if (i < missions.length - 1 && claimed > 0) {
        _localTs = DateTime.now().millisecondsSinceEpoch;
        final mlResp = await api.getMissionList();
        if (mlResp.isSuccess && mounted) {
          _missionData = mlResp.dataMap;
          _serverTs = mlResp.time ?? _localTs;
        }
        // Delay between claims
        await Future.delayed(Duration(seconds: _delaySeconds.round()));
      }
    }

    // Verify score change
    if (mounted) {
      final verifyResp = await api.getMissionList();
      if (verifyResp.isSuccess) {
        _missionData = verifyResp.dataMap;
        _serverTs = verifyResp.time ?? _serverTs;
      }

      setState(() => _autoClaiming = false);
      final afterScore = _missionData?['accScoreRsp']?['score'] as String? ?? '0';
      messenger.showSnackBar(
        SnackBar(
          content: Text('本次领取 $claimed 个任务，积分 $beforeScore → $afterScore'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreInfo = _missionData?['accScoreRsp'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分中心'),
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
                    if (scoreInfo != null) ScoreHeader(scoreInfo: scoreInfo),
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

  Widget _buildMissionTab() {
    final exhausted = _exhaustedRefIds();
    final missions = (_missionData?['missions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .where((m) => (m['score'] as int? ?? 0) > 0) // 跳过无积分任务
            .toList() ??
        [];

    final claimable = missions.any((m) => !exhausted.contains(m['refId'] as String? ?? ''));

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
        itemCount: missions.length + (claimable ? 2 : 0), // +1 for button, +1 for slider
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
          if (claimable && i == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('间隔', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: _delaySeconds,
                          min: 5,
                          max: 30,
                          divisions: 25,
                          label: '${_delaySeconds.round()}秒',
                          onChanged: (v) => setState(() => _delaySeconds = v),
                        ),
                      ),
                      Text('${_delaySeconds.round()}秒', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          }

          final idx = claimable ? i - 2 : i;
          final m = missions[idx];
          final refId = m['refId'] as String? ?? '';
          final name = m['name'] as String? ?? '未知任务';
          final desc = m['desc'] as String? ?? '';
          final score = m['score'] as int? ?? 0;
          final claiming = _claimingTasks.contains(refId);
          final isExhausted = exhausted.contains(refId);
          final remaining = _remainingFromLimits(refId);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isExhausted ? Colors.grey[100] : Colors.orange[50],
                child: Text('+$score',
                    style: TextStyle(
                      color: isExhausted ? Colors.grey : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '$desc\n${isExhausted ? "今日已用完" : "可领 $remaining 次"}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              isThreeLine: true,
              trailing: claiming
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : isExhausted
                      ? const Text('已领完', style: TextStyle(color: Colors.grey, fontSize: 12))
                      : TextButton(
                          onPressed: () async {
                            final ok = await _claimScore(m);
                            if (ok) _loadData();
                          },
                          child: const Text('领取'),
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    final items = _scoreHistory ?? [];

    return Column(
      children: [
        _buildSrcFilterBar(),
        Expanded(
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(child: Text('暂无积分记录', style: TextStyle(color: Colors.grey, fontSize: 16))),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i] as Map<String, dynamic>;
                      final data = item['data'] as Map<String, dynamic>?;
                      final src = item['src'] as int? ?? 0;
                      final isIncome = src != 105;
                      final scoreStr = data?['score'] as String? ?? '0';
                      final score = int.tryParse(scoreStr) ?? 0;
                      final adName = data?['adName'] as String?;
                      final msg = item['msg'] as String? ?? '';
                      final title = adName ?? msg;
                      final ctime = item['ctime'] as int?;
                      final timeStr = ctime != null
                          ? DateTime.fromMillisecondsSinceEpoch(ctime).toString().substring(0, 16)
                          : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                          title: Text(title),
                          subtitle: Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}$score',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSrcFilterBar() {
    const filters = <int?, String>{
      null: '全部',
      101: '收入',
      105: '支出',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: filters.entries.map((e) {
          final selected = _srcFilter == e.key;
          final color = e.key == null ? null : (e.key == 101 ? Colors.green : Colors.red);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) {
                setState(() => _srcFilter = e.key);
                _loadData();
              },
              selectedColor: color?.withAlpha(40),
              checkmarkColor: color,
            ),
          );
        }).toList(),
      ),
    );
  }
}
