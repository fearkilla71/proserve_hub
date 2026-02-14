import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/paint_color_database_service.dart';

/// Brand color database screen — browse, search, and save paint colors.
class PaintColorDatabaseScreen extends StatefulWidget {
  const PaintColorDatabaseScreen({super.key});

  @override
  State<PaintColorDatabaseScreen> createState() =>
      _PaintColorDatabaseScreenState();
}

class _PaintColorDatabaseScreenState extends State<PaintColorDatabaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _brandFilter;
  String? _familyFilter;
  final _searchCtrl = TextEditingController();
  final _svc = PaintColorDatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paint Colors'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'Search'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBrowseTab(scheme),
          _buildSearchTab(scheme),
          _buildFavoritesTab(scheme),
        ],
      ),
    );
  }

  // ── Browse Tab ──
  Widget _buildBrowseTab(ColorScheme scheme) {
    return Column(
      children: [
        // Brand filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _filterChip(
                'All',
                _brandFilter == null,
                () => setState(() => _brandFilter = null),
              ),
              ...PaintColorDatabaseService.brands.map(
                (brand) => _filterChip(
                  brand,
                  _brandFilter == brand,
                  () => setState(() => _brandFilter = brand),
                ),
              ),
            ],
          ),
        ),
        // Family filter
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _miniChip(
                'All',
                _familyFilter == null,
                () => setState(() => _familyFilter = null),
              ),
              ...PaintColorDatabaseService.families.map(
                (fam) => _miniChip(
                  fam,
                  _familyFilter == fam,
                  () => setState(() => _familyFilter = fam),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildColorGrid(_getFilteredColors())),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredColors() {
    var colors = PaintColorDatabaseService.allColors;
    if (_brandFilter != null) {
      colors = colors.where((c) => c['brand'] == _brandFilter).toList();
    }
    if (_familyFilter != null) {
      colors = colors.where((c) => c['family'] == _familyFilter).toList();
    }
    return colors;
  }

  // ── Search Tab ──
  Widget _buildSearchTab(ColorScheme scheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, code, or brand…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.palette,
                        size: 64,
                        color: scheme.primary.withValues(alpha: .3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Search paint colors',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : _buildColorGrid(_svc.searchColors(_searchQuery)),
        ),
      ],
    );
  }

  // ── Favorites Tab ──
  Widget _buildFavoritesTab(ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _svc.watchFavorites(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: scheme.primary.withValues(alpha: .3),
                ),
                const SizedBox(height: 12),
                const Text('No favorite colors yet'),
                Text(
                  'Tap the heart on any color to save it',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            return _ColorCard(
              color: data,
              isFavorite: true,
              onToggleFavorite: () => _svc.removeFavorite(docs[i].id),
            );
          },
        );
      },
    );
  }

  // ── Color Grid ──
  Widget _buildColorGrid(List<Map<String, dynamic>> colors) {
    if (colors.isEmpty) {
      return const Center(child: Text('No colors found'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: colors.length,
      itemBuilder: (context, i) {
        return _ColorCard(
          color: colors[i],
          onToggleFavorite: () => _svc.addFavorite(colors[i]),
        );
      },
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _miniChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

class _ColorCard extends StatelessWidget {
  final Map<String, dynamic> color;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _ColorCard({
    required this.color,
    this.isFavorite = false,
    required this.onToggleFavorite,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final hex = color['hex'] as String? ?? '#CCCCCC';
    final bgColor = _hexToColor(hex);
    final brightness = ThemeData.estimateBrightnessForColor(bgColor);
    final textColor = brightness == Brightness.light
        ? Colors.black87
        : Colors.white;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: .3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    color['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    color['code'] ?? '',
                    style: TextStyle(fontSize: 9, color: textColor),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggleFavorite();
                },
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isFavorite
                      ? Colors.red
                      : textColor.withValues(alpha: .6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final hex = color['hex'] as String? ?? '#CCCCCC';
    final bgColor = _hexToColor(hex);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              color['name'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              color['code'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              color['brand'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Family: ${color['family'] ?? ''}'),
            Text('Hex: $hex', style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hex));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Copied: $hex')));
            },
            child: const Text('Copy Hex'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onToggleFavorite();
            },
            child: Text(isFavorite ? 'Remove Favorite' : 'Add to Favorites'),
          ),
        ],
      ),
    );
  }
}
