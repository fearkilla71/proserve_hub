import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/zip_locations.dart';
import '../utils/distance.dart';

Future<List<QueryDocumentSnapshot>> findMatchingContractors(
  String jobZip,
) async {
  final zip = jobZip.trim();
  if (zip.isEmpty) return [];
  if (!zipLocations.containsKey(zip)) return [];

  final jobLoc = zipLocations[zip]!;

  final snapshot = await FirebaseFirestore.instance
      .collection('contractors')
      .get();

  return snapshot.docs.where((doc) {
    final data = doc.data();
    final contractorZip = (data['zip'] ?? '').toString().trim();

    if (contractorZip.isEmpty) return false;
    if (!zipLocations.containsKey(contractorZip)) return false;

    final contractorLoc = zipLocations[contractorZip]!;
    final radius = (data['radius'] ?? 0).toDouble();

    final dist = distanceInMiles(
      jobLoc['lat']!,
      jobLoc['lng']!,
      contractorLoc['lat']!,
      contractorLoc['lng']!,
    );

    return dist <= radius;
  }).toList();
}
