import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// Escrow management tab — real-time tracking of all escrow bookings,
/// status filters, financial overview, and admin actions.
class EscrowAdminTab extends StatefulWidget {
  const EscrowAdminTab({super.key, this.canWrite = true});
  final bool canWrite;

  @override
  State<EscrowAdminTab> createState() => _EscrowAdminTabState();
}

class _EscrowAdminTabState extends State<EscrowAdminTab> {
  final _db = FirebaseFirestore.instance;
  final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _dateFmt = DateFormat('MMM d, yyyy h:mm a');

  String _statusFilter = 'all';
  String _searchQuery = '';
  bool _loading = true;

  List<Map<String, dynamic>> _bookings = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load all escrow bookings
      Query<Map<String, dynamic>> query = _db
          .collection('escrow_bookings')
          .orderBy('createdAt', descending: true);

      if (_statusFilter != 'all') {
        query = _db
            .collection('escrow_bookings')
            .where('status', isEqualTo: _statusFilter)
            .orderBy('createdAt', descending: true);
      }

      final snap = await query.limit(200).get();
      final bookings = <Map<String, dynamic>>[];

      // Aggregate summary
      double totalEscrowValue = 0;
      double totalPlatformFees = 0;
      double totalContractorPayouts = 0;
      int funded = 0, released = 0, cancelled = 0, offered = 0;
      int rated = 0;
      double ratingSum = 0;
      double totalSavings = 0;
      int premiumLeadsUsed = 0;

      for (final doc in snap.docs) {
        final d = doc.data();
        d['id'] = doc.id;

        // Resolve customer name
        final customerId = d['customerId'] as String?;
        if (customerId != null) {
          try {
            final userSnap = await _db
                .collection('users')
                .doc(customerId)
                .get();
            d['customerName'] =
                userSnap.data()?['displayName'] ??
                userSnap.data()?['name'] ??
                'Unknown';
            d['customerEmail'] = userSnap.data()?['email'] ?? '';
          } catch (_) {
            d['customerName'] = 'Unknown';
          }
        }

        // Resolve contractor name
        final contractorId = d['contractorId'] as String?;
        if (contractorId != null) {
          try {
            final cSnap = await _db
                .collection('contractors')
                .doc(contractorId)
                .get();
            d['contractorName'] =
                cSnap.data()?['businessName'] ??
                cSnap.data()?['name'] ??
                'Unassigned';
          } catch (_) {
            d['contractorName'] = 'Unknown';
          }
        } else {
          d['contractorName'] = 'Unassigned';
        }

        bookings.add(d);

        // Summary stats
        final price = (d['aiPrice'] as num?)?.toDouble() ?? 0;
        final fee = (d['platformFee'] as num?)?.toDouble() ?? 0;
        final payout = (d['contractorPayout'] as num?)?.toDouble() ?? 0;
        final status = d['status'] as String? ?? '';
        final savings = (d['savingsAmount'] as num?)?.toDouble() ?? 0;
        final rating = (d['priceFairnessRating'] as num?)?.toInt();
        final leadCost = (d['premiumLeadCost'] as num?)?.toInt() ?? 0;

        if (status == 'funded' ||
            status == 'customerConfirmed' ||
            status == 'contractorConfirmed' ||
            status == 'released') {
          totalEscrowValue += price;
          totalPlatformFees += fee;
          totalContractorPayouts += payout;
          totalSavings += savings;
        }

        switch (status) {
          case 'offered':
            offered++;
            break;
          case 'funded':
          case 'customerConfirmed':
          case 'contractorConfirmed':
            funded++;
            break;
          case 'released':
            released++;
            break;
          case 'cancelled':
          case 'declined':
            cancelled++;
            break;
        }

        if (rating != null) {
          rated++;
          ratingSum += rating;
        }
        if (contractorId != null && status != 'offered') {
          premiumLeadsUsed += leadCost;
        }
      }

      setState(() {
        _bookings = bookings;
        _summary = {
          'totalEscrowValue': totalEscrowValue,
          'totalPlatformFees': totalPlatformFees,
          'totalContractorPayouts': totalContractorPayouts,
          'totalSavings': totalSavings,
          'offered': offered,
          'funded': funded,
          'released': released,
          'cancelled': cancelled,
          'total': bookings.length,
          'avgRating': rated > 0 ? ratingSum / rated : 0.0,
          'ratedCount': rated,
          'premiumLeadsUsed': premiumLeadsUsed,
        };
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading escrow data: $e');
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_searchQuery.isEmpty) return _bookings;
    final q = _searchQuery.toLowerCase();
    return _bookings.where((b) {
      final service = (b['service'] as String? ?? '').toLowerCase();
      final customer = (b['customerName'] as String? ?? '').toLowerCase();
      final contractor = (b['contractorName'] as String? ?? '').toLowerCase();
      final zip = (b['zip'] as String? ?? '').toLowerCase();
      final id = (b['id'] as String? ?? '').toLowerCase();
      return service.contains(q) ||
          customer.contains(q) ||
          contractor.contains(q) ||
          zip.contains(q) ||
          id.contains(q);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'offered':
        return AdminColors.accent2;
      case 'funded':
        return AdminColors.accent;
      case 'customerConfirmed':
      case 'contractorConfirmed':
        return AdminColors.warning;
      case 'released':
        return const Color(0xFF4CAF50);
      case 'cancelled':
      case 'declined':
        return AdminColors.error;
      default:
        return AdminColors.muted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'offered':
        return 'Offered';
      case 'funded':
        return 'Funded';
      case 'customerConfirmed':
        return 'Customer OK';
      case 'contractorConfirmed':
        return 'Contractor OK';
      case 'released':
        return 'Released';
      case 'cancelled':
        return 'Cancelled';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Title row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escrow Tracking',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadData,
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  _buildExportButton(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Financial summary cards ──
          _buildFinancialSummary(),
          const SizedBox(height: 20),

          // ── Status pipeline ──
          _buildStatusPipeline(),
          const SizedBox(height: 20),

          // ── Search + Filter ──
          _buildSearchFilter(),
          const SizedBox(height: 16),

          // ── Bookings list ──
          ..._filteredBookings.map(_buildBookingCard),

          if (_filteredBookings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: AdminColors.muted),
                    const SizedBox(height: 12),
                    Text(
                      'No escrow bookings found',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonLoader(
              width: 180,
              height: 22,
              borderRadius: BorderRadius.circular(6),
            ),
            SkeletonLoader(
              width: 90,
              height: 36,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: List.generate(
            4,
            (_) => SkeletonLoader(
              width: double.infinity,
              height: 80,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonLoader(
              width: double.infinity,
              height: 100,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // ── Financial summary ──

  Widget _buildFinancialSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 4 ? 2.2 : 2.5,
          children: [
            _summaryCard(
              'Total Escrow Value',
              _currencyFmt.format(_summary['totalEscrowValue'] ?? 0),
              Icons.account_balance_wallet,
              AdminColors.accent2,
            ),
            _summaryCard(
              'Platform Fees Earned',
              _currencyFmt.format(_summary['totalPlatformFees'] ?? 0),
              Icons.monetization_on,
              AdminColors.accent,
            ),
            _summaryCard(
              'Contractor Payouts',
              _currencyFmt.format(_summary['totalContractorPayouts'] ?? 0),
              Icons.payments,
              AdminColors.accent3,
            ),
            _summaryCard(
              'Customer Savings',
              _currencyFmt.format(_summary['totalSavings'] ?? 0),
              Icons.savings,
              AdminColors.warning,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AdminColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: AdminColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status pipeline ──

  Widget _buildStatusPipeline() {
    final stages = [
      {
        'label': 'Offered',
        'count': _summary['offered'] ?? 0,
        'color': AdminColors.accent2,
        'icon': Icons.local_offer,
      },
      {
        'label': 'Funded',
        'count': _summary['funded'] ?? 0,
        'color': AdminColors.accent,
        'icon': Icons.lock,
      },
      {
        'label': 'Released',
        'count': _summary['released'] ?? 0,
        'color': const Color(0xFF4CAF50),
        'icon': Icons.check_circle,
      },
      {
        'label': 'Cancelled',
        'count': _summary['cancelled'] ?? 0,
        'color': AdminColors.error,
        'icon': Icons.cancel,
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Escrow Pipeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_summary['total'] ?? 0} total',
                  style: TextStyle(color: AdminColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: stages.map((s) {
                return Expanded(
                  child: _pipelineStage(
                    s['label'] as String,
                    s['count'] as int,
                    s['color'] as Color,
                    s['icon'] as IconData,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Rating + Premium leads row
            Row(
              children: [
                _metricChip(
                  Icons.star,
                  'Avg Rating: ${(_summary['avgRating'] as double? ?? 0).toStringAsFixed(1)}',
                  AdminColors.warning,
                ),
                const SizedBox(width: 12),
                _metricChip(
                  Icons.verified,
                  '${_summary['ratedCount'] ?? 0} rated',
                  AdminColors.accent2,
                ),
                const SizedBox(width: 12),
                _metricChip(
                  Icons.bolt,
                  '${_summary['premiumLeadsUsed'] ?? 0} premium credits used',
                  AdminColors.accent3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipelineStage(String label, int count, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: AdminColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: TextStyle(color: AdminColors.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search + Filter ──

  Widget _buildSearchFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by service, customer, contractor, ZIP, ID...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AdminColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _statusFilter,
          onChanged: (v) {
            if (v != null) {
              setState(() => _statusFilter = v);
              _loadData();
            }
          },
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'offered', child: Text('Offered')),
            DropdownMenuItem(value: 'funded', child: Text('Funded')),
            DropdownMenuItem(
              value: 'customerConfirmed',
              child: Text('Customer OK'),
            ),
            DropdownMenuItem(
              value: 'contractorConfirmed',
              child: Text('Contractor OK'),
            ),
            DropdownMenuItem(value: 'released', child: Text('Released')),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            DropdownMenuItem(value: 'declined', child: Text('Declined')),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return FilledButton.icon(
      onPressed: _exportCsv,
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Export CSV'),
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }

  void _exportCsv() {
    final lines = <String>[
      'ID,Service,Customer,Contractor,ZIP,AI Price,Platform Fee,Contractor Payout,Status,Market Price,Savings,Discount %,Rating,Created',
    ];

    for (final b in _filteredBookings) {
      final created = (b['createdAt'] as Timestamp?)?.toDate();
      lines.add(
        [
          b['id'] ?? '',
          (b['service'] ?? '').toString().replaceAll(',', ';'),
          (b['customerName'] ?? '').toString().replaceAll(',', ';'),
          (b['contractorName'] ?? '').toString().replaceAll(',', ';'),
          b['zip'] ?? '',
          (b['aiPrice'] as num?)?.toStringAsFixed(2) ?? '',
          (b['platformFee'] as num?)?.toStringAsFixed(2) ?? '',
          (b['contractorPayout'] as num?)?.toStringAsFixed(2) ?? '',
          b['status'] ?? '',
          (b['estimatedMarketPrice'] as num?)?.toStringAsFixed(2) ?? '',
          (b['savingsAmount'] as num?)?.toStringAsFixed(2) ?? '',
          (b['discountPercent'] as num?)?.toStringAsFixed(1) ?? '',
          (b['priceFairnessRating'] as num?)?.toString() ?? '',
          created != null ? _dateFmt.format(created) : '',
        ].join(','),
      );
    }

    // Download via web
    _downloadTextFile(
      'escrow_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      lines.join('\n'),
    );
  }

  void _downloadTextFile(String filename, String content) {
    try {
      final bytes = utf8.encode(content);
      final base64Data = base64Encode(bytes);
      final dataUrl = 'data:text/csv;base64,$base64Data';
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = dataUrl;
      anchor.download = filename;
      anchor.style.display = 'none';
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $filename'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // ── Individual booking card ──

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';
    final color = _statusColor(status);
    final price = (booking['aiPrice'] as num?)?.toDouble() ?? 0;
    final fee = (booking['platformFee'] as num?)?.toDouble() ?? 0;
    final payout = (booking['contractorPayout'] as num?)?.toDouble() ?? 0;
    final created = (booking['createdAt'] as Timestamp?)?.toDate();
    final service = booking['service'] as String? ?? 'Unknown';
    final customer = booking['customerName'] as String? ?? 'Unknown';
    final contractor = booking['contractorName'] as String? ?? 'Unassigned';
    final zip = booking['zip'] as String? ?? '';
    final savings = (booking['savingsAmount'] as num?)?.toDouble();
    final discount = (booking['discountPercent'] as num?)?.toDouble();
    final rating = (booking['priceFairnessRating'] as num?)?.toInt();
    final id = booking['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBookingDetail(booking),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Status + Service + ID
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      service,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    id.substring(0, id.length > 8 ? 8 : id.length),
                    style: TextStyle(
                      color: AdminColors.muted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Customer / Contractor / ZIP
              Row(
                children: [
                  _infoChip(Icons.person, customer),
                  const SizedBox(width: 12),
                  _infoChip(Icons.construction, contractor),
                  const SizedBox(width: 12),
                  _infoChip(Icons.location_on, zip),
                ],
              ),
              const SizedBox(height: 10),

              // Row 3: Financial details
              Row(
                children: [
                  _financialPill(
                    'Price',
                    _currencyFmt.format(price),
                    AdminColors.ink,
                  ),
                  const SizedBox(width: 8),
                  _financialPill(
                    'Fee',
                    _currencyFmt.format(fee),
                    AdminColors.accent,
                  ),
                  const SizedBox(width: 8),
                  _financialPill(
                    'Payout',
                    _currencyFmt.format(payout),
                    AdminColors.accent2,
                  ),
                  if (savings != null && savings > 0) ...[
                    const SizedBox(width: 8),
                    _financialPill(
                      'Saved',
                      _currencyFmt.format(savings),
                      const Color(0xFF4CAF50),
                    ),
                  ],
                  if (discount != null && discount > 0) ...[
                    const SizedBox(width: 8),
                    _financialPill(
                      'Disc.',
                      '${discount.toStringAsFixed(0)}%',
                      AdminColors.accent3,
                    ),
                  ],
                  const Spacer(),
                  if (rating != null)
                    Row(
                      children: [
                        ...List.generate(
                          rating,
                          (_) => const Icon(
                            Icons.star,
                            size: 14,
                            color: AdminColors.warning,
                          ),
                        ),
                        ...List.generate(
                          5 - rating,
                          (_) => Icon(
                            Icons.star_border,
                            size: 14,
                            color: AdminColors.muted.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (created != null) ...[
                const SizedBox(height: 6),
                Text(
                  _dateFmt.format(created),
                  style: TextStyle(color: AdminColors.muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdminColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: AdminColors.muted, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _financialPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(color: AdminColors.muted, fontSize: 10),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail dialog ──

  void _showBookingDetail(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';
    final color = _statusColor(status);
    final id = booking['id'] as String? ?? '';
    final price = (booking['aiPrice'] as num?)?.toDouble() ?? 0;
    final fee = (booking['platformFee'] as num?)?.toDouble() ?? 0;
    final payout = (booking['contractorPayout'] as num?)?.toDouble() ?? 0;
    final created = (booking['createdAt'] as Timestamp?)?.toDate();
    final funded = (booking['fundedAt'] as Timestamp?)?.toDate();
    final released = (booking['releasedAt'] as Timestamp?)?.toDate();
    final customerConf = (booking['customerConfirmedAt'] as Timestamp?)
        ?.toDate();
    final contractorConf = (booking['contractorConfirmedAt'] as Timestamp?)
        ?.toDate();
    final service = booking['service'] as String? ?? '';
    final customer = booking['customerName'] as String? ?? '';
    final customerEmail = booking['customerEmail'] as String? ?? '';
    final contractor = booking['contractorName'] as String? ?? '';
    final zip = booking['zip'] as String? ?? '';
    final marketPrice = (booking['estimatedMarketPrice'] as num?)?.toDouble();
    final savings = (booking['savingsAmount'] as num?)?.toDouble();
    final savingsPct = (booking['savingsPercent'] as num?)?.toDouble();
    final discount = (booking['discountPercent'] as num?)?.toDouble();
    final origPrice = (booking['originalAiPrice'] as num?)?.toDouble();
    final rating = (booking['priceFairnessRating'] as num?)?.toInt();
    final ratingComment = booking['ratingComment'] as String?;
    final priceLock = (booking['priceLockExpiry'] as Timestamp?)?.toDate();
    final leadCost = (booking['premiumLeadCost'] as num?)?.toInt() ?? 3;
    final jobId = booking['jobId'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          service,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // IDs
                  _detailRow('Escrow ID', id),
                  _detailRow('Job ID', jobId),
                  _detailRow('ZIP', zip),
                  const Divider(height: 24),

                  // People
                  Text(
                    'People',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AdminColors.accent2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _detailRow('Customer', '$customer ($customerEmail)'),
                  _detailRow('Contractor', contractor),
                  const Divider(height: 24),

                  // Financials
                  Text(
                    'Financials',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AdminColors.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (origPrice != null)
                    _detailRow(
                      'Original AI Price',
                      _currencyFmt.format(origPrice),
                    ),
                  if (discount != null)
                    _detailRow(
                      'Instant Discount',
                      '${discount.toStringAsFixed(0)}%',
                    ),
                  _detailRow('Final AI Price', _currencyFmt.format(price)),
                  _detailRow('Platform Fee (5%)', _currencyFmt.format(fee)),
                  _detailRow('Contractor Payout', _currencyFmt.format(payout)),
                  if (marketPrice != null)
                    _detailRow(
                      'Est. Market Price',
                      _currencyFmt.format(marketPrice),
                    ),
                  if (savings != null)
                    _detailRow(
                      'Customer Savings',
                      '${_currencyFmt.format(savings)} (${savingsPct?.toStringAsFixed(0) ?? ''}%)',
                    ),
                  _detailRow('Premium Lead Cost', '$leadCost credits'),
                  const Divider(height: 24),

                  // Timeline
                  Text(
                    'Timeline',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AdminColors.accent3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (created != null)
                    _detailRow('Created', _dateFmt.format(created)),
                  if (priceLock != null)
                    _detailRow(
                      'Price Lock Expires',
                      _dateFmt.format(priceLock),
                    ),
                  if (funded != null)
                    _detailRow('Funded', _dateFmt.format(funded)),
                  if (customerConf != null)
                    _detailRow(
                      'Customer Confirmed',
                      _dateFmt.format(customerConf),
                    ),
                  if (contractorConf != null)
                    _detailRow(
                      'Contractor Confirmed',
                      _dateFmt.format(contractorConf),
                    ),
                  if (released != null)
                    _detailRow('Released', _dateFmt.format(released)),

                  // Rating
                  if (rating != null) ...[
                    const Divider(height: 24),
                    Text(
                      'Customer Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AdminColors.warning,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(
                          rating,
                          (_) => const Icon(
                            Icons.star,
                            size: 20,
                            color: AdminColors.warning,
                          ),
                        ),
                        ...List.generate(
                          5 - rating,
                          (_) => Icon(
                            Icons.star_border,
                            size: 20,
                            color: AdminColors.muted.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$rating/5',
                          style: TextStyle(
                            color: AdminColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (ratingComment != null && ratingComment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '"$ratingComment"',
                          style: TextStyle(
                            color: AdminColors.muted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 20),
                  // Admin actions
                  if (status == 'funded' ||
                      status == 'customerConfirmed' ||
                      status == 'contractorConfirmed')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _forceRelease(id);
                            },
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text('Force Release'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _forceCancel(id);
                            },
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('Force Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: AdminColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Admin actions ──

  Future<void> _forceRelease(String escrowId) async {
    try {
      await _db.collection('escrow_bookings').doc(escrowId).update({
        'status': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
        'adminReleasedNote': 'Force released by admin',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escrow funds force released')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _forceCancel(String escrowId) async {
    try {
      await _db.collection('escrow_bookings').doc(escrowId).update({
        'status': 'cancelled',
        'adminCancelledNote': 'Force cancelled by admin',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escrow booking cancelled')));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
