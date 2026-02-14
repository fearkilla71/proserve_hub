import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Predefined stage templates per service type.
/// Contractors can customize, but these are the defaults.
const Map<String, List<Map<String, String>>> defaultStageTemplates = {
  'interior_painting': [
    {'key': 'booked', 'label': 'Job Booked', 'icon': 'check_circle'},
    {
      'key': 'materials',
      'label': 'Materials Purchased',
      'icon': 'shopping_cart',
    },
    {'key': 'prep', 'label': 'Prep & Taping', 'icon': 'format_paint'},
    {'key': 'primer', 'label': 'Primer Applied', 'icon': 'brush'},
    {'key': 'coat1', 'label': 'First Coat Done', 'icon': 'layers'},
    {'key': 'coat2', 'label': 'Second Coat Done', 'icon': 'layers'},
    {'key': 'touchup', 'label': 'Touch-ups & Detail', 'icon': 'auto_fix_high'},
    {
      'key': 'cleanup',
      'label': 'Cleanup & Walk-through',
      'icon': 'cleaning_services',
    },
    {'key': 'complete', 'label': 'Job Complete', 'icon': 'verified'},
  ],
  'exterior_painting': [
    {'key': 'booked', 'label': 'Job Booked', 'icon': 'check_circle'},
    {
      'key': 'materials',
      'label': 'Materials Purchased',
      'icon': 'shopping_cart',
    },
    {
      'key': 'power_wash',
      'label': 'Power Wash / Surface Prep',
      'icon': 'water_drop',
    },
    {
      'key': 'scrape_sand',
      'label': 'Scraping & Sanding',
      'icon': 'construction',
    },
    {'key': 'primer', 'label': 'Primer Applied', 'icon': 'brush'},
    {'key': 'coat1', 'label': 'First Coat Done', 'icon': 'layers'},
    {'key': 'coat2', 'label': 'Second Coat Done', 'icon': 'layers'},
    {'key': 'trim', 'label': 'Trim & Detail Work', 'icon': 'auto_fix_high'},
    {
      'key': 'cleanup',
      'label': 'Cleanup & Walk-through',
      'icon': 'cleaning_services',
    },
    {'key': 'complete', 'label': 'Job Complete', 'icon': 'verified'},
  ],
  'drywall_repair': [
    {'key': 'booked', 'label': 'Job Booked', 'icon': 'check_circle'},
    {
      'key': 'materials',
      'label': 'Materials Purchased',
      'icon': 'shopping_cart',
    },
    {'key': 'demo', 'label': 'Damaged Area Removed', 'icon': 'construction'},
    {'key': 'patch', 'label': 'Patch Installed', 'icon': 'grid_view'},
    {'key': 'tape_mud', 'label': 'Tape & Mud Applied', 'icon': 'format_paint'},
    {'key': 'sand', 'label': 'Sanding Complete', 'icon': 'blur_on'},
    {'key': 'prime_paint', 'label': 'Primed & Painted', 'icon': 'brush'},
    {
      'key': 'cleanup',
      'label': 'Cleanup & Inspection',
      'icon': 'cleaning_services',
    },
    {'key': 'complete', 'label': 'Job Complete', 'icon': 'verified'},
  ],
  'pressure_washing': [
    {'key': 'booked', 'label': 'Job Booked', 'icon': 'check_circle'},
    {'key': 'equipment', 'label': 'Equipment Setup', 'icon': 'build'},
    {'key': 'pre_treat', 'label': 'Pre-Treatment Applied', 'icon': 'science'},
    {'key': 'washing', 'label': 'Washing In Progress', 'icon': 'water_drop'},
    {'key': 'detail', 'label': 'Detail & Edges Done', 'icon': 'auto_fix_high'},
    {'key': 'rinse', 'label': 'Final Rinse', 'icon': 'shower'},
    {'key': 'complete', 'label': 'Job Complete', 'icon': 'verified'},
  ],
  'cabinets': [
    {'key': 'booked', 'label': 'Job Booked', 'icon': 'check_circle'},
    {
      'key': 'materials',
      'label': 'Materials Purchased',
      'icon': 'shopping_cart',
    },
    {
      'key': 'doors_off',
      'label': 'Doors & Hardware Removed',
      'icon': 'door_front',
    },
    {'key': 'clean_sand', 'label': 'Clean & Sand', 'icon': 'blur_on'},
    {'key': 'primer', 'label': 'Primer Applied', 'icon': 'brush'},
    {'key': 'coat1', 'label': 'First Coat Done', 'icon': 'layers'},
    {'key': 'coat2', 'label': 'Second Coat / Finish', 'icon': 'layers'},
    {
      'key': 'hardware',
      'label': 'Hardware & Doors Reinstalled',
      'icon': 'handyman',
    },
    {
      'key': 'cleanup',
      'label': 'Final Inspection',
      'icon': 'cleaning_services',
    },
    {'key': 'complete', 'label': 'Job Complete', 'icon': 'verified'},
  ],
};

/// Service for managing the live job timeline ("pizza tracker").
///
/// Firestore structure:
///   job_requests/{jobId}/timeline/{stageKey}
///     - key: String
///     - label: String
///     - icon: String
///     - status: 'pending' | 'in_progress' | 'completed'
///     - completedAt: Timestamp?
///     - completedBy: String? (uid)
///     - note: String?
///     - photoUrl: String?
///     - order: int
class JobTimelineService {
  JobTimelineService._();
  static final instance = JobTimelineService._();

  final _db = FirebaseFirestore.instance;
  static const _jobs = 'job_requests';
  static const _sub = 'timeline';

  /// Initialize timeline stages for a job. Called once when contractor starts.
  Future<void> initializeTimeline(String jobId, String serviceType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final ref = _db.collection(_jobs).doc(jobId).collection(_sub);
    final existing = await ref.limit(1).get();
    if (existing.docs.isNotEmpty) return; // Already initialized

    final normalizedType = serviceType
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    final template =
        defaultStageTemplates[normalizedType] ??
        defaultStageTemplates['interior_painting']!;

    final batch = _db.batch();
    for (var i = 0; i < template.length; i++) {
      final stage = template[i];
      final docRef = ref.doc(stage['key']!);
      batch.set(docRef, {
        'key': stage['key'],
        'label': stage['label'],
        'icon': stage['icon'],
        'status': i == 0 ? 'completed' : 'pending', // 'booked' is auto-done
        'completedAt': i == 0 ? FieldValue.serverTimestamp() : null,
        'completedBy': i == 0 ? uid : null,
        'note': null,
        'photoUrl': null,
        'order': i,
      });
    }

    // Also mark the current stage on the parent doc for quick reads
    batch.update(_db.collection(_jobs).doc(jobId), {
      'timelineCurrentStage': template[0]['key'],
      'timelineInitialized': true,
      'timelineStageCount': template.length,
      'timelineCompletedCount': 1,
    });

    await batch.commit();
  }

  /// Advance a stage to completed and optionally add a note/photo.
  Future<void> completeStage(
    String jobId,
    String stageKey, {
    String? note,
    String? photoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final ref = _db.collection(_jobs).doc(jobId).collection(_sub).doc(stageKey);

    await ref.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'completedBy': uid,
      if (note != null) 'note': note,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });

    // Find next pending stage and mark it in_progress
    final allStages = await _db
        .collection(_jobs)
        .doc(jobId)
        .collection(_sub)
        .orderBy('order')
        .get();

    int completedCount = 0;
    String? nextStage;
    for (final doc in allStages.docs) {
      final data = doc.data();
      if (data['status'] == 'completed') {
        completedCount++;
      } else {
        nextStage ??= doc.id;
      }
    }

    // Update parent doc
    await _db.collection(_jobs).doc(jobId).update({
      'timelineCurrentStage': nextStage ?? stageKey,
      'timelineCompletedCount': completedCount,
    });

    // Mark next stage as in_progress
    if (nextStage != null) {
      await _db
          .collection(_jobs)
          .doc(jobId)
          .collection(_sub)
          .doc(nextStage)
          .update({'status': 'in_progress'});
    }
  }

  /// Stream all timeline stages for a job, ordered.
  Stream<List<Map<String, dynamic>>> watchTimeline(String jobId) {
    return _db
        .collection(_jobs)
        .doc(jobId)
        .collection(_sub)
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList(),
        );
  }

  /// Get timeline as a one-time read.
  Future<List<Map<String, dynamic>>> getTimeline(String jobId) async {
    final snap = await _db
        .collection(_jobs)
        .doc(jobId)
        .collection(_sub)
        .orderBy('order')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }
}
