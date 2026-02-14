import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized offline sync service.
///
/// Responsibilities:
///  - Monitor connectivity and expose a global [isOnline] ValueNotifier.
///  - Queue Firestore write operations attempted while offline
///    and replay them when connectivity returns.
///  - Cache frequently accessed data (estimates, calculator inputs)
///    locally so screens can display stale-while-revalidate content.
///  - Track pending-sync count for UI indicators.
class OfflineSyncService {
  OfflineSyncService._();
  static final instance = OfflineSyncService._();

  // ── connectivity ──────────────────────────────────────────────────────

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  final ValueNotifier<int> pendingSyncCount = ValueNotifier(0);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _initialized = false;

  /// Queue of write operations to replay when back online.
  final List<_QueuedWrite> _writeQueue = [];

  /// Initialize once at app start.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Check current state
    final results = await Connectivity().checkConnectivity();
    isOnline.value = results.any((r) => r != ConnectivityResult.none);

    // Listen for changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !isOnline.value;
      isOnline.value = online;

      // When coming back online, flush the write queue.
      if (online && wasOffline) {
        _flushQueue();
      }
    });

    // Load any queued writes persisted from a previous session.
    await _loadPersistedQueue();
  }

  void dispose() {
    _connectivitySub?.cancel();
    isOnline.dispose();
    pendingSyncCount.dispose();
  }

  // ── Write queue ───────────────────────────────────────────────────────

  /// Enqueue a Firestore write.  If online it executes immediately; if offline
  /// it is stored and replayed later.
  Future<void> enqueueWrite({
    required String collection,
    required String? docId,
    required Map<String, dynamic> data,
    required WriteOp op,
  }) async {
    if (isOnline.value) {
      await _executeWrite(collection, docId, data, op);
      return;
    }

    final queued = _QueuedWrite(
      collection: collection,
      docId: docId,
      data: data,
      op: op,
      createdAt: DateTime.now(),
    );
    _writeQueue.add(queued);
    pendingSyncCount.value = _writeQueue.length;
    await _persistQueue();
  }

  Future<void> _executeWrite(
    String collection,
    String? docId,
    Map<String, dynamic> data,
    WriteOp op,
  ) async {
    final fs = FirebaseFirestore.instance;
    switch (op) {
      case WriteOp.set:
        if (docId != null) {
          await fs
              .collection(collection)
              .doc(docId)
              .set(data, SetOptions(merge: true));
        } else {
          await fs.collection(collection).add(data);
        }
        break;
      case WriteOp.update:
        if (docId != null) {
          await fs.collection(collection).doc(docId).update(data);
        }
        break;
      case WriteOp.delete:
        if (docId != null) {
          await fs.collection(collection).doc(docId).delete();
        }
        break;
    }
  }

  Future<void> _flushQueue() async {
    if (_writeQueue.isEmpty) return;

    final copy = List<_QueuedWrite>.from(_writeQueue);
    _writeQueue.clear();
    pendingSyncCount.value = 0;

    int failures = 0;
    for (final w in copy) {
      try {
        await _executeWrite(w.collection, w.docId, w.data, w.op);
      } catch (e) {
        debugPrint('[OfflineSync] Replay failed: $e');
        _writeQueue.add(w);
        failures++;
      }
    }
    pendingSyncCount.value = _writeQueue.length;
    await _persistQueue();

    if (failures == 0) {
      debugPrint('[OfflineSync] All ${copy.length} queued writes replayed.');
    } else {
      debugPrint(
        '[OfflineSync] $failures/${copy.length} writes failed, re-queued.',
      );
    }
  }

  // ── Queue persistence (SharedPreferences) ─────────────────────────────

  static const _queueKey = 'offline_write_queue';

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _writeQueue.map((w) => w.toJson()).toList();
    await prefs.setString(_queueKey, jsonEncode(list));
  }

  Future<void> _loadPersistedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _writeQueue.addAll(list.map(_QueuedWrite.fromJson));
      pendingSyncCount.value = _writeQueue.length;
      if (isOnline.value && _writeQueue.isNotEmpty) {
        _flushQueue();
      }
    } catch (e) {
      debugPrint('[OfflineSync] Failed to load persisted queue: $e');
    }
  }

  // ── Local data cache ──────────────────────────────────────────────────

  /// Cache arbitrary JSON data locally under [key].
  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_$key', jsonEncode(data));
  }

  /// Retrieve cached data, or null if not present.
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Cache a list of maps (e.g. recent estimates).
  Future<void> cacheList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_list_$key', jsonEncode(items));
  }

  /// Retrieve a cached list of maps.
  Future<List<Map<String, dynamic>>> getCachedList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_list_$key');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Remove cached data.
  Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
    await prefs.remove('cache_list_$key');
  }

  // ── Estimate draft cache ──────────────────────────────────────────────

  /// Save the current estimator flow state so it survives app restarts
  /// and offline periods.
  Future<void> cacheEstimateDraft({
    required String serviceType,
    required String description,
    required Map<String, double> quantities,
    required Map<String, String> answers,
    double? laborOverride,
  }) async {
    await cacheData('estimate_draft', {
      'serviceType': serviceType,
      'description': description,
      'quantities': quantities.map((k, v) => MapEntry(k, v)),
      'answers': answers,
      if (laborOverride != null) 'laborOverride': laborOverride,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Load a previously-cached estimate draft (or null).
  Future<Map<String, dynamic>?> loadEstimateDraft() async {
    return getCachedData('estimate_draft');
  }

  /// Clear any saved estimate draft.
  Future<void> clearEstimateDraft() async {
    await clearCache('estimate_draft');
  }

  // ── Calculator cache ──────────────────────────────────────────────────

  /// Cache calculator inputs for offline use.
  Future<void> cacheCalculatorInputs({
    required String calculatorType,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> results,
  }) async {
    final list = await getCachedList('calculator_history');
    list.insert(0, {
      'calculatorType': calculatorType,
      'inputs': inputs,
      'results': results,
      'savedAt': DateTime.now().toIso8601String(),
    });
    // Keep last 20 entries
    if (list.length > 20) list.removeRange(20, list.length);
    await cacheList('calculator_history', list);
  }

  /// Get cached calculator history.
  Future<List<Map<String, dynamic>>> getCalculatorHistory() async {
    return getCachedList('calculator_history');
  }

  // ── Saved estimates cache ─────────────────────────────────────────────

  /// Cache a completed estimate for offline viewing.
  Future<void> cacheCompletedEstimate({
    required String estimateId,
    required String serviceType,
    required double total,
    required double materialCost,
    required double laborCost,
    required List<Map<String, dynamic>> materials,
    String? clientName,
  }) async {
    final list = await getCachedList('completed_estimates');
    list.insert(0, {
      'estimateId': estimateId,
      'serviceType': serviceType,
      'total': total,
      'materialCost': materialCost,
      'laborCost': laborCost,
      'materials': materials,
      'clientName': clientName,
      'savedAt': DateTime.now().toIso8601String(),
    });
    if (list.length > 50) list.removeRange(50, list.length);
    await cacheList('completed_estimates', list);
  }

  /// Get cached estimates for offline browsing.
  Future<List<Map<String, dynamic>>> getCachedEstimates() async {
    return getCachedList('completed_estimates');
  }
}

// ── Supporting types ──────────────────────────────────────────────────────

/// Type of Firestore write operation.
enum WriteOp { set, update, delete }

class _QueuedWrite {
  final String collection;
  final String? docId;
  final Map<String, dynamic> data;
  final WriteOp op;
  final DateTime createdAt;

  _QueuedWrite({
    required this.collection,
    required this.docId,
    required this.data,
    required this.op,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'collection': collection,
    'docId': docId,
    'data': data,
    'op': op.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _QueuedWrite.fromJson(Map<String, dynamic> json) => _QueuedWrite(
    collection: json['collection'] as String,
    docId: json['docId'] as String?,
    data: (json['data'] as Map).cast<String, dynamic>(),
    op: WriteOp.values.firstWhere((e) => e.name == json['op']),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
