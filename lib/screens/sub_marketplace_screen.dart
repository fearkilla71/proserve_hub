import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Subcontractor Marketplace
///
/// Post overflow jobs for verified subs to bid on within the app.
/// The platform takes a referral cut.
/// ─────────────────────────────────────────────────────────────────────────────
class SubMarketplaceScreen extends StatefulWidget {
  const SubMarketplaceScreen({super.key});

  @override
  State<SubMarketplaceScreen> createState() => _SubMarketplaceScreenState();
}

class _SubMarketplaceScreenState extends State<SubMarketplaceScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Tabs ──
  int _tabIndex = 0; // 0 = Browse, 1 = My Posts, 2 = My Bids

  // ── Browse ──
  List<Map<String, dynamic>> _listings = [];
  bool _loadingListings = true;

  // ── My Posts ──
  List<Map<String, dynamic>> _myPosts = [];
  bool _loadingMyPosts = true;

  // ── My Bids ──
  List<Map<String, dynamic>> _myBids = [];
  bool _loadingMyBids = true;

  static const double _platformFeePercent = 5.0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadListings(), _loadMyPosts(), _loadMyBids()]);
  }

  // ── Load data ─────────────────────────────────────────────────────────────

  Future<void> _loadListings() async {
    setState(() => _loadingListings = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sub_marketplace')
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _listings = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingListings = false);
  }

  Future<void> _loadMyPosts() async {
    setState(() => _loadingMyPosts = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sub_marketplace')
          .where('postedBy', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      _myPosts = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingMyPosts = false);
  }

  Future<void> _loadMyBids() async {
    setState(() => _loadingMyBids = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sub_marketplace_bids')
          .where('bidderId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      _myBids = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingMyBids = false);
  }

  // ── Post job ──────────────────────────────────────────────────────────────

  Future<void> _showPostJobDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final zipCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    String serviceType = 'Interior Painting';
    String urgency = 'Normal';
    DateTime? deadline;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Post Overflow Job'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Job Title *',
                    hintText: 'e.g. 3BR Interior Repaint',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  decoration: const InputDecoration(labelText: 'Service Type'),
                  items:
                      [
                            'Interior Painting',
                            'Exterior Painting',
                            'Cabinet Painting',
                            'Drywall Repair',
                            'Pressure Washing',
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) =>
                      setDialogState(() => serviceType = v ?? serviceType),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Scope of work, special requirements…',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Job Address'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: zipCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ZIP Code',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: budgetCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Budget (\$)',
                          prefixText: '\$ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: urgency,
                  decoration: const InputDecoration(labelText: 'Urgency'),
                  items: ['Urgent', 'Normal', 'Flexible']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => urgency = v ?? 'Normal'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: Text(
                    deadline != null
                        ? DateFormat('MMM d, yyyy').format(deadline!)
                        : 'Set Deadline (optional)',
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setDialogState(() => deadline = d);
                  },
                ),
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(ctx).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Platform fee: ${_platformFeePercent.toStringAsFixed(0)}% '
                            'of accepted bid',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                ctx,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'title': titleCtrl.text.trim(),
                  'serviceType': serviceType,
                  'description': descCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'zip': zipCtrl.text.trim(),
                  'budget': double.tryParse(budgetCtrl.text.trim()) ?? 0,
                  'urgency': urgency,
                  'deadline': deadline?.toIso8601String(),
                });
              },
              child: const Text('Post Job'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      // Get poster info.
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('sub_marketplace').add({
        ...result,
        'postedBy': _uid,
        'posterName':
            userData['businessName'] ?? userData['displayName'] ?? 'Contractor',
        'posterCity': userData['city'] ?? '',
        'posterState': userData['state'] ?? '',
        'status': 'open',
        'bidCount': 0,
        'platformFeePercent': _platformFeePercent,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posted to marketplace ✓')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error posting: $e')));
      }
    }
  }

  // ── Submit Bid ────────────────────────────────────────────────────────────

  Future<void> _showBidDialog(Map<String, dynamic> listing) async {
    if (listing['postedBy'] == _uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't bid on your own listing")),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final timelineCtrl = TextEditingController(text: '3 days');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Bid'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                listing['title']?.toString() ?? 'Job',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (listing['budget'] != null && (listing['budget'] as num) > 0)
                Text(
                  'Budget: \$${(listing['budget'] as num).toStringAsFixed(0)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Bid (\$) *',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timelineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estimated Timeline',
                  hintText: 'e.g. 3 days, 1 week',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note to poster',
                  hintText: 'Why you\'re the best fit…',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(ctx).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_platformFeePercent.toStringAsFixed(0)}% platform '
                          'fee applies on acceptance',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim());
              if (amt == null || amt <= 0) return;
              Navigator.pop(ctx, {
                'amount': amt,
                'timeline': timelineCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
              });
            },
            child: const Text('Submit Bid'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('sub_marketplace_bids').add({
        'listingId': listing['id'],
        'listingTitle': listing['title'],
        'bidderId': _uid,
        'bidderName':
            userData['businessName'] ?? userData['displayName'] ?? 'Contractor',
        'bidderCity': userData['city'] ?? '',
        ...result,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment bid count.
      await FirebaseFirestore.instance
          .collection('sub_marketplace')
          .doc(listing['id'])
          .update({'bidCount': FieldValue.increment(1)});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bid submitted ✓')));
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── View bids on my post ──────────────────────────────────────────────────

  Future<void> _showBidsForPost(Map<String, dynamic> post) async {
    final snap = await FirebaseFirestore.instance
        .collection('sub_marketplace_bids')
        .where('listingId', isEqualTo: post['id'])
        .orderBy('amount')
        .get();

    final bids = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) {
          final cs = Theme.of(ctx).colorScheme;
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Bids for ${post['title'] ?? 'Job'}',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${bids.length} bid(s) received',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (bids.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No bids yet',
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
                )
              else
                ...bids.map(
                  (bid) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                child: Text(
                                  (bid['bidderName']?.toString() ?? 'C')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bid['bidderName']?.toString() ??
                                          'Contractor',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (bid['bidderCity'] != null)
                                      Text(
                                        bid['bidderCity'].toString(),
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${(bid['amount'] as num?)?.toStringAsFixed(0) ?? '?'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                          if (bid['timeline'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: cs.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  bid['timeline'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (bid['note'] != null &&
                              bid['note'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(bid['note'].toString()),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (bid['status'] == 'pending') ...[
                                OutlinedButton(
                                  onPressed: () async {
                                    await _updateBidStatus(
                                      bid['id'],
                                      'rejected',
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  child: const Text('Decline'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () async {
                                    await _acceptBid(bid, post);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  child: const Text('Accept'),
                                ),
                              ] else
                                Chip(
                                  label: Text(
                                    bid['status']?.toString().toUpperCase() ??
                                        'PENDING',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateBidStatus(String bidId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('sub_marketplace_bids')
          .doc(bidId)
          .update({'status': status});
      await _loadAll();
    } catch (_) {}
  }

  Future<void> _acceptBid(
    Map<String, dynamic> bid,
    Map<String, dynamic> post,
  ) async {
    try {
      // Accept this bid.
      await FirebaseFirestore.instance
          .collection('sub_marketplace_bids')
          .doc(bid['id'])
          .update({'status': 'accepted'});

      // Close the listing.
      await FirebaseFirestore.instance
          .collection('sub_marketplace')
          .doc(post['id'])
          .update({
            'status': 'awarded',
            'awardedTo': bid['bidderId'],
            'awardedName': bid['bidderName'],
            'awardedAmount': bid['amount'],
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bid accepted! ${bid['bidderName']} awarded the job.',
            ),
          ),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sub Marketplace'),
          bottom: TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: const [
              Tab(icon: Icon(Icons.storefront), text: 'Browse'),
              Tab(icon: Icon(Icons.post_add), text: 'My Posts'),
              Tab(icon: Icon(Icons.gavel), text: 'My Bids'),
            ],
          ),
        ),
        floatingActionButton: _tabIndex == 0 || _tabIndex == 1
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Post Job'),
                onPressed: _showPostJobDialog,
              )
            : null,
        body: TabBarView(
          children: [
            _buildBrowseTab(cs),
            _buildMyPostsTab(cs),
            _buildMyBidsTab(cs),
          ],
        ),
      ),
    );
  }

  // ── Browse Tab ────────────────────────────────────────────────────────────

  Widget _buildBrowseTab(ColorScheme cs) {
    if (_loadingListings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text('No open listings', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Post a job'),
              onPressed: _showPostJobDialog,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _buildListingCard(_listings[i], cs),
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing, ColorScheme cs) {
    final urgency = listing['urgency']?.toString() ?? 'Normal';
    final urgencyColor = urgency == 'Urgent'
        ? Colors.red
        : urgency == 'Flexible'
        ? Colors.grey
        : Colors.orange;
    final budget = (listing['budget'] as num?)?.toDouble() ?? 0;
    final bidCount = (listing['bidCount'] as num?)?.toInt() ?? 0;
    final ts = (listing['createdAt'] as Timestamp?)?.toDate();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBidDialog(listing),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing['title']?.toString() ?? 'Job',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(urgency, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: urgencyColor),
                    labelStyle: TextStyle(color: urgencyColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (listing['serviceType'] != null)
                Chip(
                  avatar: const Icon(Icons.build_circle, size: 14),
                  label: Text(
                    listing['serviceType'].toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (listing['description'] != null &&
                  listing['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  listing['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (listing['zip'] != null) ...[
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: cs.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing['zip'].toString(),
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (budget > 0) ...[
                    Icon(Icons.attach_money, size: 14, color: Colors.green),
                    Text(
                      budget.toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.gavel, size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    '$bidCount bids',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  const Spacer(),
                  if (ts != null)
                    Text(
                      DateFormat('MMM d').format(ts),
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      (listing['posterName']?.toString() ?? 'C')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    listing['posterName']?.toString() ?? 'Contractor',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (listing['posterCity'] != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '· ${listing['posterCity']}',
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── My Posts Tab ──────────────────────────────────────────────────────────

  Widget _buildMyPostsTab(ColorScheme cs) {
    if (_loadingMyPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.post_add_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              "You haven't posted any jobs",
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Post a job'),
              onPressed: _showPostJobDialog,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyPosts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myPosts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final post = _myPosts[i];
          final status = post['status']?.toString() ?? 'open';
          final bidCount = (post['bidCount'] as num?)?.toInt() ?? 0;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (status == 'open' ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.15),
                child: Icon(
                  status == 'open' ? Icons.storefront : Icons.check_circle,
                  color: status == 'open' ? Colors.green : Colors.grey,
                ),
              ),
              title: Text(
                post['title']?.toString() ?? 'Job',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('$bidCount bids · ${status.toUpperCase()}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showBidsForPost(post),
            ),
          );
        },
      ),
    );
  }

  // ── My Bids Tab ───────────────────────────────────────────────────────────

  Widget _buildMyBidsTab(ColorScheme cs) {
    if (_loadingMyBids) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myBids.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              "You haven't placed any bids",
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 8),
            const Text('Browse listings to submit bids'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyBids,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myBids.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final bid = _myBids[i];
          final status = bid['status']?.toString() ?? 'pending';
          final statusColor = status == 'accepted'
              ? Colors.green
              : status == 'rejected'
              ? Colors.red
              : Colors.orange;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(
                  status == 'accepted'
                      ? Icons.check_circle
                      : status == 'rejected'
                      ? Icons.cancel
                      : Icons.hourglass_bottom,
                  color: statusColor,
                ),
              ),
              title: Text(
                bid['listingTitle']?.toString() ?? 'Job',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '\$${(bid['amount'] as num?)?.toStringAsFixed(0) ?? '?'} · '
                '${status.toUpperCase()}',
              ),
              trailing: Text(
                bid['timeline']?.toString() ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        },
      ),
    );
  }
}
