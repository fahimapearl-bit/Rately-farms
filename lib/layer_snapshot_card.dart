import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'layer_performance_screen.dart';

/// Small dashboard header card. Shows only when an Active Egg Production batch exists.
class LayerSnapshotCard extends StatefulWidget {
  const LayerSnapshotCard({super.key});

  @override
  State<LayerSnapshotCard> createState() => _LayerSnapshotCardState();
}

class _LayerSnapshotCardState extends State<LayerSnapshotCard> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _batch;
  Map<String, dynamic>? _latest;
  int _currentBirds = 0;

  num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final batches = await _client
          .from('batches')
          .select('id, name, initial_birds, production_type, status, start_date')
          .eq('status', 'Active')
          .ilike('production_type', '%Egg%')
          .order('start_date', ascending: false)
          .limit(1);
      if (batches.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final batch = Map<String, dynamic>.from(batches.first);
      final logs = await _client
          .from('layer_daily_logs')
          .select('*')
          .eq('batch_id', batch['id'])
          .order('log_date', ascending: false);

      num lost = 0;
      for (final l in logs) {
        lost += _n(l['mortality']) + _n(l['culled'] ?? l['culling']);
      }
      final birds = (_n(batch['initial_birds']) - lost).toInt();

      if (mounted) {
        setState(() {
          _batch = batch;
          _latest = logs.isEmpty ? null : Map<String, dynamic>.from(logs.first);
          _currentBirds = birds < 0 ? 0 : birds;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _batch == null) return const SizedBox.shrink();

    final today = DateTime.now().toIso8601String().split('T').first;
    final log = _latest;
    final isToday = log != null && '${log['log_date']}'.startsWith(today);
    final eggs = log == null ? 0 : _n(log['total_eggs'] ?? (_n(log['good_eggs']) + _n(log['damaged_eggs'])));
    final feedKg = log == null ? 0 : _n(log['feed_consumed_kg'] ?? log['feed_consumed'] ?? log['feed_kg']);
    final hdp = _currentBirds > 0 ? eggs / _currentBirds * 100 : 0;
    final feedPerEgg = eggs > 0 ? feedKg * 1000 / eggs : 0;
    final mortality = log == null ? 0 : _n(log['mortality']);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        elevation: 0,
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.amber.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LayerPerformanceScreen()),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.egg_outlined, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Layer Snapshot · ${_batch!['name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(isToday ? 'Today' : 'Latest',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                if (log == null)
                  Text('No entry yet — Tap to add',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700))
                else ...[
                  Row(
                    children: [
                      _metric('HDP', '${hdp.toStringAsFixed(1)}%'),
                      _metric('Eggs', eggs.toStringAsFixed(0)),
                      _metric('Feed/egg', '${feedPerEgg.toStringAsFixed(0)} g'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Birds $_currentBirds · Mortality ${mortality.toStringAsFixed(0)} · Updated ${log['log_date']}'
                    '${isToday ? '' : '  (No entry today — Tap to add)'}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
