import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/zip_locations.dart';
import '../utils/distance.dart';
import 'zip_lookup_service.dart';

Future<List<QueryDocumentSnapshot>> findMatchingContractors(
  String jobZip,
) async {
  final zip = jobZip.trim();
  if (zip.isEmpty) return [];

  // Resolve job ZIP via cache, hardcoded map, or geocoding
  final jobLoc =
      ZipLookupService.instance.lookupCached(zip) ??
      zipLocations[zip] ??
      await ZipLookupService.instance.lookup(zip);
  if (jobLoc == null) return [];

  final snapshot = await FirebaseFirestore.instance
      .collection('contractors')
      .get();

  return snapshot.docs.where((doc) {
    final data = doc.data();
    final contractorZip = (data['zip'] ?? '').toString().trim();

    if (contractorZip.isEmpty) return false;

    final contractorLoc =
        ZipLookupService.instance.lookupCached(contractorZip) ??
        zipLocations[contractorZip];
    if (contractorLoc == null) return false;

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
