import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/ai_usage_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AI Bid Analyzer
///
/// Paste a competitor's bid or RFP document → AI extracts line items,
/// compares against your pricing engine, flags where you're over/under,
/// and suggests a competitive counter-bid.
/// ─────────────────────────────────────────────────────────────────────────────
class BidAnalyzerScreen extends StatefulWidget {
  const BidAnalyzerScreen({super.key});

  @override
  State<BidAnalyzerScreen> createState() => _BidAnalyzerScreenState();
}

class _BidAnalyzerScreenState extends State<BidAnalyzerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final _inputCtrl = TextEditingController();
  final _jobLabelCtrl = TextEditingController();

  bool _analyzing = false;
  String? _error;

  // ── AI results ──
  List<Map<String, dynamic>> _lineItems = [];
  String? _summary;
  String? _counterBidSuggestion;
  double? _theirTotal;
  double? _yourTotal;

  // ── History ──
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _jobLabelCtrl.dispose();
    super.dispose();
  }

  // ── Paste from clipboard ──────────────────────────────────────────────────

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _inputCtrl.text = data.text!;
      setState(() {});
    }
  }

  // ── Analyze ───────────────────────────────────────────────────────────────

  Future<void> _analyzeBid() async {
    final text = _inputCtrl.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bidAnalyzerPasteRequired)));
      return;
    }

    // Rate limit.
    final limitMsg = await AiUsageService.instance.checkLimit('bidAnalyzer');
    if (limitMsg != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(limitMsg)));
      }
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
      _lineItems = [];
      _summary = null;
      _counterBidSuggestion = null;
      _theirTotal = null;
      _yourTotal = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeBid',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final resp = await callable.call<dynamic>({
        'bidText': text,
        'jobLabel': _jobLabelCtrl.text.trim(),
      });

      final data = resp.data as Map<dynamic, dynamic>? ?? {};

      final items =
          (data['lineItems'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      // comparison data available via data['comparison'] if needed

      await AiUsageService.instance.recordUsage('bidAnalyzer');

      if (mounted) {
        setState(() {
          _lineItems = items;
          _summary = data['summary']?.toString();
          _counterBidSuggestion = data['counterBid']?.toString();
          _theirTotal = (data['theirTotal'] as num?)?.toDouble();
          _yourTotal = (data['yourTotal'] as num?)?.toDouble();
          _analyzing = false;
        });
      }

      // Save to history.
      _saveAnalysis(text);
    } catch (e) {
      // Fallback: local extraction when Cloud Function unavailable
      _generateLocalAnalysis(text);
    }
  }

  void _generateLocalAnalysis(String text) {
    // Parse simple line items from text.
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final items = <Map<String, dynamic>>[];
    double total = 0;

    for (final line in lines) {
      // Try to extract a dollar amount.
      final moneyMatch = RegExp(r'\$\s*([\d,]+\.?\d*)').firstMatch(line);
      if (moneyMatch != null) {
        final amount =
            double.tryParse(moneyMatch.group(1)!.replaceAll(',', '')) ?? 0;
        // Remove the dollar amount from the line to get the description.
        final desc = line
            .replaceAll(moneyMatch.group(0)!, '')
            .replaceAll(RegExp(r'^\s*[-•*]\s*'), '')
            .trim();

        items.add({
          'description': desc.isEmpty ? 'Line item' : desc,
          'theirPrice': amount,
          'yourPrice': null,
          'difference': null,
          'flag': 'unknown',
        });
        total += amount;
      }
    }

    if (items.isEmpty) {
      // No dollar amounts found — just list all lines.
      for (final line in lines.take(20)) {
        items.add({
          'description': line
              .replaceAll(RegExp(r'^\s*[-•*\d.]+\s*'), '')
              .trim(),
          'theirPrice': null,
          'yourPrice': null,
          'difference': null,
          'flag': 'review',
        });
      }
    }

    setState(() {
      _lineItems = items;
      _theirTotal = total > 0 ? total : null;
      _yourTotal = null;
      _summary = AppLocalizations.of(context)!.bidAnalyzerLocalSummary(
        items.length,
        total > 0
            ? AppLocalizations.of(
                context,
              )!.bidAnalyzerLocalSummaryTotal('\$${total.toStringAsFixed(0)}')
            : '',
      );
      _counterBidSuggestion = null;
      _analyzing = false;
    });

    _saveAnalysis(text);
  }

  Future<void> _saveAnalysis(String inputText) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('bid_analyses')
          .add({
            'jobLabel': _jobLabelCtrl.text.trim(),
            'inputText': inputText.substring(
              0,
              inputText.length > 2000 ? 2000 : inputText.length,
            ),
            'lineItemCount': _lineItems.length,
            'theirTotal': _theirTotal,
            'yourTotal': _yourTotal,
            'summary': _summary,
            'counterBid': _counterBidSuggestion,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _loadHistory();
    } catch (_) {}
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('bid_analyses')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      _history = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.toolBidAnalyzerTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.analytics_outlined),
                text: l10n.bidAnalyzerAnalyzeTab,
              ),
              Tab(icon: const Icon(Icons.history), text: l10n.history),
            ],
          ),
        ),
        body: TabBarView(children: [_buildAnalyzeTab(), _buildHistoryTab()]),
      ),
    );
  }

  // ── Analyze Tab ───────────────────────────────────────────────────────────

  Widget _buildAnalyzeTab() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Job label
        TextField(
          controller: _jobLabelCtrl,
          decoration: InputDecoration(
            labelText: l10n.bidAnalyzerJobLabel,
            hintText: l10n.bidAnalyzerJobHint,
            prefixIcon: const Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 16),

        // Input area
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.bidAnalyzerInputTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: l10n.bidAnalyzerPasteClipboard,
                      onPressed: _pasteFromClipboard,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.bidAnalyzerInputSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inputCtrl,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: l10n.bidAnalyzerInputHint,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.bidAnalyzerCharacters(_inputCtrl.text.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Analyze button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _analyzing
                  ? l10n.bidAnalyzerAnalyzing
                  : l10n.toolActionAnalyzeBid,
            ),
            onPressed: _analyzing ? null : _analyzeBid,
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),

        // ── Results ──
        if (_summary != null) ...[
          const SizedBox(height: 20),
          _buildSummaryCard(cs),
        ],

        if (_lineItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildLineItemsTable(cs),
        ],

        if (_counterBidSuggestion != null) ...[
          const SizedBox(height: 16),
          _buildCounterBidCard(cs),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.bidAnalyzerSummaryTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_theirTotal != null || _yourTotal != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (_theirTotal != null)
                      Expanded(
                        child: _totalChip(
                          l10n.bidAnalyzerTheirTotal,
                          '\$${_theirTotal!.toStringAsFixed(0)}',
                          Colors.red,
                        ),
                      ),
                    if (_theirTotal != null && _yourTotal != null)
                      const SizedBox(width: 12),
                    if (_yourTotal != null)
                      Expanded(
                        child: _totalChip(
                          l10n.bidAnalyzerYourPrice,
                          '\$${_yourTotal!.toStringAsFixed(0)}',
                          Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            Text(_summary!, style: TextStyle(color: cs.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }

  Widget _totalChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsTable(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bidAnalyzerLineItems(_lineItems.length),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Header row
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    l10n.description,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: cs.outline,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l10n.bidAnalyzerTheirs,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: cs.outline,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l10n.bidAnalyzerYours,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: cs.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
            const Divider(),
            // Data rows
            ..._lineItems.map((item) {
              final flag = item['flag']?.toString() ?? 'unknown';
              final flagIcon = flag == 'over'
                  ? Icons.arrow_upward
                  : flag == 'under'
                  ? Icons.arrow_downward
                  : flag == 'match'
                  ? Icons.check
                  : Icons.help_outline;
              final flagColor = flag == 'over'
                  ? Colors.red
                  : flag == 'under'
                  ? Colors.green
                  : flag == 'match'
                  ? Colors.blue
                  : Colors.grey;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        item['description']?.toString() ?? l10n.item,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['theirPrice'] != null
                            ? '\$${(item['theirPrice'] as num).toStringAsFixed(0)}'
                            : '—',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['yourPrice'] != null
                            ? '\$${(item['yourPrice'] as num).toStringAsFixed(0)}'
                            : '—',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Icon(flagIcon, size: 16, color: flagColor),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterBidCard(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.bidAnalyzerCounterBidTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_counterBidSuggestion!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l10n.copyToClipboard),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _counterBidSuggestion!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.copiedToClipboard)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.history, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.bidAnalyzerNoAnalyses,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.bidAnalyzerNoAnalysesSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () =>
                        DefaultTabController.of(context).animateTo(0),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(l10n.bidAnalyzerStartAnalysis),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = _history[i];
        final ts = (a['createdAt'] as Timestamp?)?.toDate();
        final theirTotal = (a['theirTotal'] as num?)?.toDouble();

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.analytics, color: cs.primary),
            ),
            title: Text(
              a['jobLabel']?.toString().isNotEmpty == true
                  ? a['jobLabel'].toString()
                  : l10n.bidAnalyzerFallbackTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${l10n.bidAnalyzerHistoryItems('${a['lineItemCount'] ?? '?'}')}'
              '${theirTotal != null ? ' · \$${theirTotal.toStringAsFixed(0)}' : ''}',
            ),
            trailing: ts != null
                ? Text(
                    DateFormat('MMM d').format(ts),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            onTap: () => _showHistoryDetail(a),
          ),
        );
      },
    );
  }

  void _showHistoryDetail(Map<String, dynamic> analysis) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              analysis['jobLabel']?.toString().isNotEmpty == true
                  ? analysis['jobLabel'].toString()
                  : l10n.bidAnalyzerFallbackTitle,
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (analysis['summary'] != null)
              Text(analysis['summary'].toString()),
            if (analysis['counterBid'] != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.bidAnalyzerCounterBidLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(analysis['counterBid'].toString()),
            ],
          ],
        ),
      ),
    );
  }
}
