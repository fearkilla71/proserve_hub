import 'package:flutter/material.dart';

import '../services/loyalty_service.dart';

/// Seasonal contractor leaderboard ranked by XP.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>>? _leaders;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await LoyaltyService.instance.getLeaderboard(limit: 25);
    if (!mounted) {
      return;
    }
    setState(() {
      _leaders = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _leaders == null || _leaders!.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No leaderboard data yet',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Top 3 podium ──
                if (_leaders!.length >= 3) _buildPodium(scheme),
                const SizedBox(height: 8),
                // ── Rest of list ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _leaders!.length,
                    itemBuilder: (context, index) {
                      if (index < 3) return const SizedBox.shrink();
                      final entry = _leaders![index];
                      return _LeaderTile(
                        rank: index + 1,
                        entry: entry,
                        scheme: scheme,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPodium(ColorScheme scheme) {
    final first = _leaders![0];
    final second = _leaders![1];
    final third = _leaders![2];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A0E3A),
            scheme.primary.withValues(alpha: .8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          _PodiumSpot(
            rank: 2,
            entry: second,
            height: 90,
            color: const Color(0xFFC0C0C0),
          ),
          // 1st place
          _PodiumSpot(
            rank: 1,
            entry: first,
            height: 120,
            color: const Color(0xFFFFD700),
          ),
          // 3rd place
          _PodiumSpot(
            rank: 3,
            entry: third,
            height: 70,
            color: const Color(0xFFCD7F32),
          ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;
  final double height;
  final Color color;

  const _PodiumSpot({
    required this.rank,
    required this.entry,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final name = (entry['name'] ?? 'Unknown').toString();
    final xp = entry['xp'] ?? 0;
    final levelLabel = entry['levelLabel'] ?? 'Bronze';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1) const Text('👑', style: TextStyle(fontSize: 24)),
        CircleAvatar(
          radius: rank == 1 ? 30 : 24,
          backgroundColor: color.withValues(alpha: .3),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: rank == 1 ? 24 : 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '$xp XP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          levelLabel,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: .6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 50,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '#$rank',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;
  final ColorScheme scheme;

  const _LeaderTile({
    required this.rank,
    required this.entry,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final name = (entry['name'] ?? 'Unknown').toString();
    final xp = entry['xp'] ?? 0;
    final levelLabel = entry['levelLabel'] ?? 'Bronze';
    final jobs = entry['totalJobsCompleted'] ?? 0;
    final rating = (entry['avgRating'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            Text(
              '$levelLabel  •  $jobs jobs',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (rating > 0) ...[
              const SizedBox(width: 6),
              Icon(Icons.star, size: 14, color: Colors.amber.shade700),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$xp XP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
