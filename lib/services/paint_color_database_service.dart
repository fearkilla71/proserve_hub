import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service providing brand paint color databases for the render tool.
class PaintColorDatabaseService {
  PaintColorDatabaseService._();
  static final instance = PaintColorDatabaseService._();

  final _fs = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Favorite colors for this contractor ──
  CollectionReference<Map<String, dynamic>> get _favCol =>
      _fs.collection('contractors').doc(_uid).collection('favorite_colors');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFavorites() {
    return _favCol.orderBy('addedAt', descending: true).snapshots();
  }

  Future<void> addFavorite(Map<String, dynamic> color) async {
    await _favCol.add({...color, 'addedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeFavorite(String id) async {
    await _favCol.doc(id).delete();
  }

  // ── Search colors by name or code ──
  List<Map<String, dynamic>> searchColors(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return allColors
        .where(
          (c) =>
              (c['name'] as String).toLowerCase().contains(q) ||
              (c['code'] as String).toLowerCase().contains(q) ||
              (c['brand'] as String).toLowerCase().contains(q),
        )
        .take(50)
        .toList();
  }

  // ── Get colors by brand ──
  List<Map<String, dynamic>> getByBrand(String brand) {
    return allColors.where((c) => c['brand'] == brand).toList();
  }

  // ── Get colors by family ──
  List<Map<String, dynamic>> getByFamily(String family) {
    return allColors.where((c) => c['family'] == family).toList();
  }

  static const brands = [
    'Sherwin-Williams',
    'Benjamin Moore',
    'Behr',
    'PPG',
    'Valspar',
    'Dunn-Edwards',
  ];

  static const families = [
    'White',
    'Off-White',
    'Gray',
    'Beige',
    'Blue',
    'Green',
    'Red',
    'Yellow',
    'Brown',
    'Black',
    'Purple',
    'Orange',
    'Pink',
    'Teal',
  ];

  /// Curated database of popular paint colors.
  static final allColors = <Map<String, dynamic>>[
    // ── Sherwin-Williams ──
    {
      'brand': 'Sherwin-Williams',
      'name': 'Alabaster',
      'code': 'SW 7008',
      'hex': '#F3EDE1',
      'family': 'White',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Pure White',
      'code': 'SW 7005',
      'hex': '#F1EFEA',
      'family': 'White',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Extra White',
      'code': 'SW 7006',
      'hex': '#F1F0EC',
      'family': 'White',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Snowbound',
      'code': 'SW 7004',
      'hex': '#EDE8DF',
      'family': 'Off-White',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Greek Villa',
      'code': 'SW 7551',
      'hex': '#F0E8D7',
      'family': 'Off-White',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Agreeable Gray',
      'code': 'SW 7029',
      'hex': '#D0CBC0',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Repose Gray',
      'code': 'SW 7015',
      'hex': '#C2BFB8',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Mindful Gray',
      'code': 'SW 7016',
      'hex': '#B5B0A7',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Dovetail',
      'code': 'SW 7018',
      'hex': '#908B82',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Gauntlet Gray',
      'code': 'SW 7019',
      'hex': '#7A756E',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Iron Ore',
      'code': 'SW 7069',
      'hex': '#4D4842',
      'family': 'Black',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Tricorn Black',
      'code': 'SW 6258',
      'hex': '#353535',
      'family': 'Black',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Naval',
      'code': 'SW 6244',
      'hex': '#2E3441',
      'family': 'Blue',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Sea Salt',
      'code': 'SW 6204',
      'hex': '#CBDAD2',
      'family': 'Green',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Rainwashed',
      'code': 'SW 6211',
      'hex': '#C4D5CC',
      'family': 'Green',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Evergreen Fog',
      'code': 'SW 9130',
      'hex': '#95978B',
      'family': 'Green',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Urbane Bronze',
      'code': 'SW 7048',
      'hex': '#60564B',
      'family': 'Brown',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Accessible Beige',
      'code': 'SW 7036',
      'hex': '#CEC1AD',
      'family': 'Beige',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Kilim Beige',
      'code': 'SW 6106',
      'hex': '#C6B49A',
      'family': 'Beige',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Worldly Gray',
      'code': 'SW 7043',
      'hex': '#C5BFB3',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Amazing Gray',
      'code': 'SW 7044',
      'hex': '#BAB3A5',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Intellectual Gray',
      'code': 'SW 7045',
      'hex': '#A39E93',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Commodore',
      'code': 'SW 6524',
      'hex': '#507196',
      'family': 'Blue',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Misty',
      'code': 'SW 6232',
      'hex': '#C0CFD9',
      'family': 'Blue',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Rainstorm',
      'code': 'SW 6230',
      'hex': '#556B7D',
      'family': 'Blue',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Peppercorn',
      'code': 'SW 7674',
      'hex': '#585450',
      'family': 'Gray',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Caviar',
      'code': 'SW 6990',
      'hex': '#3A3A3C',
      'family': 'Black',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Oyster Bay',
      'code': 'SW 6206',
      'hex': '#B7C8BF',
      'family': 'Green',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Rosemary',
      'code': 'SW 6187',
      'hex': '#697764',
      'family': 'Green',
    },
    {
      'brand': 'Sherwin-Williams',
      'name': 'Creamy',
      'code': 'SW 7012',
      'hex': '#F1E7D2',
      'family': 'Off-White',
    },

    // ── Benjamin Moore ──
    {
      'brand': 'Benjamin Moore',
      'name': 'White Dove',
      'code': 'OC-17',
      'hex': '#F3EEE0',
      'family': 'White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Chantilly Lace',
      'code': 'OC-65',
      'hex': '#F5F1EC',
      'family': 'White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Simply White',
      'code': 'OC-117',
      'hex': '#F4F0E5',
      'family': 'White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Cloud White',
      'code': 'OC-130',
      'hex': '#F2EDE2',
      'family': 'White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Swiss Coffee',
      'code': 'OC-45',
      'hex': '#EFEAD7',
      'family': 'Off-White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Revere Pewter',
      'code': 'HC-172',
      'hex': '#C4BBa8',
      'family': 'Beige',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Edgecomb Gray',
      'code': 'HC-173',
      'hex': '#D0C9B8',
      'family': 'Gray',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Balboa Mist',
      'code': 'OC-27',
      'hex': '#D5CEBF',
      'family': 'Gray',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Classic Gray',
      'code': 'OC-23',
      'hex': '#DDD8CC',
      'family': 'Gray',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Stonington Gray',
      'code': 'HC-170',
      'hex': '#B5B7B4',
      'family': 'Gray',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Chelsea Gray',
      'code': 'HC-168',
      'hex': '#8B8B86',
      'family': 'Gray',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Kendall Charcoal',
      'code': 'HC-166',
      'hex': '#686863',
      'family': 'Gray',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Hale Navy',
      'code': 'HC-154',
      'hex': '#3D4957',
      'family': 'Blue',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Newburyport Blue',
      'code': 'HC-155',
      'hex': '#475667',
      'family': 'Blue',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Palladian Blue',
      'code': 'HC-144',
      'hex': '#BED2CC',
      'family': 'Teal',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Wythe Blue',
      'code': 'HC-143',
      'hex': '#A5C0B8',
      'family': 'Teal',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Sage',
      'code': '2143-40',
      'hex': '#A1A88E',
      'family': 'Green',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Caliente',
      'code': 'AF-290',
      'hex': '#C13B2A',
      'family': 'Red',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Heritage Red',
      'code': 'HC-182',
      'hex': '#9A3328',
      'family': 'Red',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Black Panther',
      'code': '2125-10',
      'hex': '#3D3D3D',
      'family': 'Black',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Decorator White',
      'code': 'CC-20',
      'hex': '#EFEDE5',
      'family': 'White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Manchester Tan',
      'code': 'HC-81',
      'hex': '#CAC0A7',
      'family': 'Beige',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Grant Beige',
      'code': 'HC-83',
      'hex': '#C4B89E',
      'family': 'Beige',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Pale Oak',
      'code': 'OC-20',
      'hex': '#D8D0C2',
      'family': 'Off-White',
    },
    {
      'brand': 'Benjamin Moore',
      'name': 'Thunder',
      'code': 'AF-685',
      'hex': '#6F6E68',
      'family': 'Gray',
    },

    // ── Behr ──
    {
      'brand': 'Behr',
      'name': 'Ultra Pure White',
      'code': '1850',
      'hex': '#F4F2ED',
      'family': 'White',
    },
    {
      'brand': 'Behr',
      'name': 'Polar Bear',
      'code': '75',
      'hex': '#F0EDE6',
      'family': 'White',
    },
    {
      'brand': 'Behr',
      'name': 'Swiss Coffee',
      'code': '1812',
      'hex': '#EDE5D3',
      'family': 'Off-White',
    },
    {
      'brand': 'Behr',
      'name': 'Silver Drop',
      'code': '790C-2',
      'hex': '#CACAC3',
      'family': 'Gray',
    },
    {
      'brand': 'Behr',
      'name': 'Dolphin Fin',
      'code': '790C-3',
      'hex': '#B9B5AC',
      'family': 'Gray',
    },
    {
      'brand': 'Behr',
      'name': 'Intellectual',
      'code': '790F-5',
      'hex': '#7E7B73',
      'family': 'Gray',
    },
    {
      'brand': 'Behr',
      'name': 'Blueprint',
      'code': 'S530-5',
      'hex': '#557594',
      'family': 'Blue',
    },
    {
      'brand': 'Behr',
      'name': 'Jade Dragon',
      'code': 'S410-6',
      'hex': '#5E7D68',
      'family': 'Green',
    },
    {
      'brand': 'Behr',
      'name': 'Toasted Cashew',
      'code': 'N280-4',
      'hex': '#B19F83',
      'family': 'Beige',
    },
    {
      'brand': 'Behr',
      'name': 'Cracked Pepper',
      'code': 'PPU18-01',
      'hex': '#494744',
      'family': 'Black',
    },
    {
      'brand': 'Behr',
      'name': 'Red Pepper',
      'code': 'P170-7',
      'hex': '#C83C24',
      'family': 'Red',
    },
    {
      'brand': 'Behr',
      'name': 'Turmeric',
      'code': 'M270-7',
      'hex': '#BE8122',
      'family': 'Yellow',
    },
    {
      'brand': 'Behr',
      'name': 'Back to Nature',
      'code': 'S340-4',
      'hex': '#A1A67A',
      'family': 'Green',
    },
    {
      'brand': 'Behr',
      'name': 'Blank Canvas',
      'code': 'DC-003',
      'hex': '#EFE7D5',
      'family': 'Off-White',
    },
    {
      'brand': 'Behr',
      'name': 'Soft Focus',
      'code': 'N130-1',
      'hex': '#E8E0D3',
      'family': 'Off-White',
    },

    // ── PPG ──
    {
      'brand': 'PPG',
      'name': 'Delicate White',
      'code': 'PPG1001-1',
      'hex': '#F0EDE6',
      'family': 'White',
    },
    {
      'brand': 'PPG',
      'name': 'Whiskers',
      'code': 'PPG1025-3',
      'hex': '#C5BCB0',
      'family': 'Gray',
    },
    {
      'brand': 'PPG',
      'name': 'Olive Sprig',
      'code': 'PPG1125-4',
      'hex': '#939483',
      'family': 'Green',
    },
    {
      'brand': 'PPG',
      'name': 'Juniper Berry',
      'code': 'PPG1145-6',
      'hex': '#3E6055',
      'family': 'Green',
    },
    {
      'brand': 'PPG',
      'name': 'Chinese Porcelain',
      'code': 'PPG1160-6',
      'hex': '#3B5E80',
      'family': 'Blue',
    },

    // ── Valspar ──
    {
      'brand': 'Valspar',
      'name': 'Du Jour',
      'code': '7002-16',
      'hex': '#F0ECE1',
      'family': 'White',
    },
    {
      'brand': 'Valspar',
      'name': 'Woodlawn Snow',
      'code': '8003-1A',
      'hex': '#E8E3D5',
      'family': 'Off-White',
    },
    {
      'brand': 'Valspar',
      'name': 'Coastal Dusk',
      'code': '5001-1C',
      'hex': '#97AAA6',
      'family': 'Teal',
    },
    {
      'brand': 'Valspar',
      'name': 'Tempered Steel',
      'code': '4003-2B',
      'hex': '#A8A59E',
      'family': 'Gray',
    },
    {
      'brand': 'Valspar',
      'name': 'Midnight Fog',
      'code': '4010-2',
      'hex': '#60605B',
      'family': 'Gray',
    },

    // ── Dunn-Edwards ──
    {
      'brand': 'Dunn-Edwards',
      'name': 'White',
      'code': 'DEW380',
      'hex': '#F5F3EE',
      'family': 'White',
    },
    {
      'brand': 'Dunn-Edwards',
      'name': 'Swiss Coffee',
      'code': 'DEW341',
      'hex': '#EDE5D3',
      'family': 'Off-White',
    },
    {
      'brand': 'Dunn-Edwards',
      'name': 'Silver Spoon',
      'code': 'DEC786',
      'hex': '#C0BDB5',
      'family': 'Gray',
    },
    {
      'brand': 'Dunn-Edwards',
      'name': 'Slate Wall',
      'code': 'DEC787',
      'hex': '#8D8A82',
      'family': 'Gray',
    },
    {
      'brand': 'Dunn-Edwards',
      'name': 'Pacific Grove',
      'code': 'DEC787',
      'hex': '#4A7A8C',
      'family': 'Blue',
    },
  ];
}
