import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// พิกัดสถานที่สำคัญและตัวเมืองในจังหวัดปัตตานี
class PattaniPlace {
  final String name;
  final String district;
  final double lat;
  final double lng;
  final String category;

  const PattaniPlace({
    required this.name,
    required this.district,
    required this.lat,
    required this.lng,
    required this.category,
  });
}

const List<PattaniPlace> kPattaniPlaces = [
  PattaniPlace(
    name: 'ม.อ. ปัตตานี (มหาวิทยาลัยสงขลานครินทร์)',
    district: 'เมืองปัตตานี',
    lat: 6.8837,
    lng: 101.2383,
    category: 'การศึกษา',
  ),
  PattaniPlace(
    name: 'โรงพยาบาลปัตตานี',
    district: 'เมืองปัตตานี',
    lat: 6.8665,
    lng: 101.2505,
    category: 'โรงพยาบาล',
  ),
  PattaniPlace(
    name: 'มัสยิดกลางจังหวัดปัตตานี',
    district: 'เมืองปัตตานี',
    lat: 6.8653,
    lng: 101.2585,
    category: 'ศาสนสถาน',
  ),
  PattaniPlace(
    name: 'ศาลเจ้าแม่ลิ้มกอเหนี่ยว (เล่งจูเกียง)',
    district: 'เมืองปัตตานี',
    lat: 6.8712,
    lng: 101.2541,
    category: 'สถานที่ท่องเที่ยว/ศาสนสถาน',
  ),
  PattaniPlace(
    name: 'ตลาดโต้รุ่ง เทศบาลเมืองปัตตานี',
    district: 'เมืองปัตตานี',
    lat: 6.8682,
    lng: 101.2530,
    category: 'ตลาด/การค้า',
  ),
  PattaniPlace(
    name: 'หอนาฬิกาเมืองปัตตานี',
    district: 'เมืองปัตตานี',
    lat: 6.8690,
    lng: 101.2515,
    category: 'แลนด์มาร์ก',
  ),
  PattaniPlace(
    name: 'บิ๊กซี ซูเปอร์เซ็นเตอร์ ปัตตานี',
    district: 'เมืองปัตตานี',
    lat: 6.8576,
    lng: 101.2427,
    category: 'ห้างสรรพสินค้า',
  ),
  PattaniPlace(
    name: 'สะพานเดชานุชิต / สวนสมเด็จฯ ปัตตานี',
    district: 'เมืองปัตตานี',
    lat: 6.8765,
    lng: 101.2482,
    category: 'สวนสาธารณะ',
  ),
  PattaniPlace(
    name: 'หาดรูสะมิแล',
    district: 'เมืองปัตตานี',
    lat: 6.8920,
    lng: 101.2320,
    category: 'ชายหาด/ธรรมชาติ',
  ),
  PattaniPlace(
    name: 'หาดตะโละกาโปร์',
    district: 'ยะหริ่ง',
    lat: 6.9405,
    lng: 101.3855,
    category: 'ชายหาด/ธรรมชาติ',
  ),
  PattaniPlace(
    name: 'วังยะหริ่ง',
    district: 'ยะหริ่ง',
    lat: 6.8672,
    lng: 101.3711,
    category: 'สถานที่ประวัติศาสตร์',
  ),
  PattaniPlace(
    name: 'มัสยิดกรือเซะ',
    district: 'เมืองปัตตานี',
    lat: 6.8722,
    lng: 101.3033,
    category: 'โบราณสถาน',
  ),
  PattaniPlace(
    name: 'วัดช้างให้ (หลวงปู่ทวด)',
    district: 'โคกโพธิ์',
    lat: 6.6710,
    lng: 101.1685,
    category: 'วัด/ศาสนสถาน',
  ),
  PattaniPlace(
    name: 'สถานีรถไฟโคกโพธิ์ / ปัตตานี',
    district: 'โคกโพธิ์',
    lat: 6.6908,
    lng: 101.1492,
    category: 'การเดินทาง',
  ),
  PattaniPlace(
    name: 'หาดแฆแฆ',
    district: 'ปะนาเระ',
    lat: 6.8415,
    lng: 101.5320,
    category: 'ชายหาด/ธรรมชาติ',
  ),
  PattaniPlace(
    name: 'ตลาดปะนาเระ',
    district: 'ปะนาเระ',
    lat: 6.8580,
    lng: 101.4925,
    category: 'ตลาด/การค้า',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอสายบุรี',
    district: 'สายบุรี',
    lat: 6.7020,
    lng: 101.6180,
    category: 'สถานที่ราชการ',
  ),
  PattaniPlace(
    name: 'หาดวาสุกรี',
    district: 'สายบุรี',
    lat: 6.7115,
    lng: 101.6322,
    category: 'ชายหาด/ธรรมชาติ',
  ),
  PattaniPlace(
    name: 'ตลาดหนองจิก',
    district: 'หนองจิก',
    lat: 6.8540,
    lng: 101.1780,
    category: 'ตลาด/การค้า',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอยะรัง',
    district: 'ยะรัง',
    lat: 6.7580,
    lng: 101.2950,
    category: 'สถานที่ราชการ',
  ),
  PattaniPlace(
    name: 'เมืองโบราณยะรัง',
    district: 'ยะรัง',
    lat: 6.7872,
    lng: 101.3090,
    category: 'โบราณสถาน',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอมายอ',
    district: 'มายอ',
    lat: 6.7450,
    lng: 101.4250,
    category: 'สถานที่ราชการ',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอทุ่งยางแดง',
    district: 'ทุ่งยางแดง',
    lat: 6.6150,
    lng: 101.4550,
    category: 'สถานที่ราชการ',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอกะพ้อ',
    district: 'กะพ้อ',
    lat: 6.5520,
    lng: 101.5580,
    category: 'สถานที่ราชการ',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอแม่ลาน',
    district: 'แม่ลาน',
    lat: 6.6430,
    lng: 101.2720,
    category: 'สถานที่ราชการ',
  ),
  PattaniPlace(
    name: 'ที่ว่าการอำเภอไม้แก่น',
    district: 'ไม้แก่น',
    lat: 6.6200,
    lng: 101.6700,
    category: 'สถานที่ราชการ',
  ),
];

/// หน้าปักหมุดแผนที่ปัตตานี Interactive Map Picker
class PattaniMapPickerPage extends StatefulWidget {
  final String? initialLocation;

  const PattaniMapPickerPage({super.key, this.initialLocation});

  @override
  State<PattaniMapPickerPage> createState() => _PattaniMapPickerPageState();
}

class _PattaniMapPickerPageState extends State<PattaniMapPickerPage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);

  // ขอบเขตพิกัดจังหวัดปัตตานี (Latitude: ~6.5 - 7.0, Longitude: ~101.0 - 101.75)
  // จุดกึ่งกลางเริ่มต้น: หอนาฬิกา / เทศบาลเมืองปัตตานี
  double currentLat = 6.8690;
  double currentLng = 101.2515;
  int zoomLevel = 14; // ระดับซูมเริ่มต้น (11 - 17)

  String locationName = 'บริเวณเมืองปัตตานี';
  String detailedAddress = 'กำลังค้นหาที่อยู่โดยละเอียด...';
  String roadOrArea = '';
  String districtText = '';
  bool isReverseGeocoding = false;
  final TextEditingController searchController = TextEditingController();
  List<PattaniPlace> filteredPlaces = [];
  bool showPlaceDrawer = false;

  @override
  void initState() {
    super.initState();
    filteredPlaces = kPattaniPlaces;

    // ถ้ามีการส่งสถานที่เดิมเข้ามา ให้ลองค้นหาพิกัดที่ตรงกัน
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      locationName = widget.initialLocation!;
      final match = kPattaniPlaces.firstWhere(
        (p) =>
            widget.initialLocation!.toLowerCase().contains(
              p.name.toLowerCase(),
            ) ||
            widget.initialLocation!.toLowerCase().contains(
              p.district.toLowerCase(),
            ),
        orElse: () => kPattaniPlaces.first,
      );
      currentLat = match.lat;
      currentLng = match.lng;
    }

    // ดึงที่อยู่ละเอียดเริ่มต้น
    _fetchPlaceName(currentLat, currentLng);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // แปลงพิกัด (lat, lng, zoom) เป็น tile index สำหรับ OpenStreetMap
  int _lngToTileX(double lng, int zoom) {
    return ((lng + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  int _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return ((1.0 -
                (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) /
                    math.pi)) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  double _tileYToLat(double y, int zoom) {
    final n = math.pi - 2.0 * math.pi * y / (1 << zoom);
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  // Reverse geocoding หาชื่อสถานที่และที่อยู่ละเอียดแบบ Google Maps จาก OpenStreetMap Nominatim
  Future<void> _fetchPlaceName(double lat, double lng) async {
    setState(() => isReverseGeocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=th',
      );
      final res = await http
          .get(url, headers: {'User-Agent': 'FindMePattaniApp/1.0'})
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final address = data['address'] as Map<String, dynamic>?;

        String title = '';
        String fullDetail = '';
        String road = '';
        String district = '';

        if (address != null) {
          final placeName =
              data['name'] ??
              address['amenity'] ??
              address['building'] ??
              address['shop'] ??
              address['office'] ??
              address['tourism'] ??
              address['historic'] ??
              address['leisure'] ??
              address['road'];

          road =
              (address['road'] ??
                      address['pedestrian'] ??
                      address['footway'] ??
                      '')
                  .toString();
          final suburb =
              (address['suburb'] ??
                      address['neighbourhood'] ??
                      address['village'] ??
                      address['hamlet'] ??
                      '')
                  .toString();
          final subDistrict =
              (address['subdistrict'] ??
                      address['town'] ??
                      address['municipality'] ??
                      '')
                  .toString();
          district =
              (address['county'] ??
                      address['city'] ??
                      address['district'] ??
                      address['state_district'] ??
                      'เมืองปัตตานี')
                  .toString();
          final province =
              (address['province'] ?? address['state'] ?? 'จ.ปัตตานี')
                  .toString();
          final postcode = (address['postcode'] ?? '').toString();

          if (placeName != null && placeName.toString().isNotEmpty) {
            title = placeName.toString();
          }

          // จัดข้อความที่อยู่ละเอียดสไตล์ Google Maps
          final parts = <String>[];
          if (road.isNotEmpty && road != title) parts.add('ถ.$road');
          if (suburb.isNotEmpty && suburb != title) parts.add(suburb);
          if (subDistrict.isNotEmpty) parts.add('ต.$subDistrict');
          if (district.isNotEmpty) {
            final dName = district
                .replaceAll('อำเภอ', '')
                .replaceAll('อ.', '')
                .trim();
            parts.add('อ.$dName');
          }
          if (province.isNotEmpty) {
            final pName = province
                .replaceAll('จังหวัด', '')
                .replaceAll('จ.', '')
                .trim();
            parts.add('จ.$pName');
          }
          if (postcode.isNotEmpty) parts.add(postcode);

          fullDetail = parts.join(' ');
        }

        if (title.isEmpty) {
          final dn = data['display_name']?.toString() ?? '';
          final items = dn
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          title = items.isNotEmpty
              ? items.first
              : 'จุดปักหมุด (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
          fullDetail = items.skip(1).take(4).join(', ');
        }

        if (fullDetail.isEmpty) {
          fullDetail =
              'พิกัด: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} อ.$district จ.ปัตตานี';
        }

        if (mounted) {
          setState(() {
            locationName = title;
            detailedAddress = fullDetail;
            roadOrArea = road;
            districtText = district;
          });
        }
      }
    } catch (_) {
      // หาก timeout หรือติด network ให้เทียบกับจุดที่ใกล้ที่สุดในฐานข้อมูลปัตตานี
      PattaniPlace? closest;
      double minDis = 999999;
      for (final p in kPattaniPlaces) {
        final d = (p.lat - lat) * (p.lat - lat) + (p.lng - lng) * (p.lng - lng);
        if (d < minDis) {
          minDis = d;
          closest = p;
        }
      }
      if (closest != null) {
        final c = closest;
        if (mounted) {
          setState(() {
            locationName = c.name;
            detailedAddress =
                'ใกล้เคียง ${c.name} อ.${c.district} จ.ปัตตานี (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
            districtText = c.district;
          });
        }
      }
    } finally {
      if (mounted) setState(() => isReverseGeocoding = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size mapSize) {
    // ปรับพิกัดตามการลากหน้าจอ
    final scale = 256.0 * (1 << zoomLevel);
    final dxLng = details.delta.dx / scale * 360.0;

    // การคำนวณระยะ lat แบบประมาณการ
    final currentTileY =
        ((1.0 -
                (math.log(
                      math.tan(currentLat * math.pi / 180.0) +
                          1.0 / math.cos(currentLat * math.pi / 180.0),
                    ) /
                    math.pi)) /
            2.0) *
        (1 << zoomLevel);
    final newTileY = currentTileY - (details.delta.dy / 256.0);
    final newLat = _tileYToLat(newTileY, zoomLevel);

    // ล็อกขอบเขตให้อยู่ในแถบปัตตานีและพื้นที่ใกล้เคียง (lat: 6.45 - 7.05, lng: 101.0 - 101.8)
    final clampedLat = newLat.clamp(6.45, 7.05);
    final clampedLng = (currentLng - dxLng).clamp(101.0, 101.8);

    setState(() {
      currentLat = clampedLat;
      currentLng = clampedLng;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _fetchPlaceName(currentLat, currentLng);
  }

  void _selectPlace(PattaniPlace place) {
    setState(() {
      currentLat = place.lat;
      currentLng = place.lng;
      zoomLevel = 15;
      locationName = place.name;
      detailedAddress =
          'อ.${place.district} จ.ปัตตานี • หมวดหมู่: ${place.category} (พิกัด: ${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)})';
      districtText = place.district;
      showPlaceDrawer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ปักหมุดแผนที่ปัตตานี',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'เลื่อนแผนที่เพื่อให้หมุดอยู่จุดที่ต้องการ',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'สถานที่สำคัญในปัตตานี',
            icon: const Icon(Icons.list_alt_rounded),
            onPressed: () {
              setState(() => showPlaceDrawer = !showPlaceDrawer);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. แผนที่ Interactive Map (OpenStreetMap Tiles)
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final tileX = _lngToTileX(currentLng, zoomLevel);
              final tileY = _latToTileY(currentLat, zoomLevel);

              // คำนวณ offset จุดศูนย์กลางของ tile ที่หมุดปักอยู่
              final exactTileX =
                  (currentLng + 180.0) / 360.0 * (1 << zoomLevel);
              final latRad = currentLat * math.pi / 180.0;
              final exactTileY =
                  ((1.0 -
                          (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) /
                              math.pi)) /
                      2.0) *
                  (1 << zoomLevel);

              final offsetX = (size.width / 2.0) - (exactTileX - tileX) * 256.0;
              final offsetY =
                  (size.height / 2.0) - (exactTileY - tileY) * 256.0;

              return GestureDetector(
                onPanUpdate: (d) => _onPanUpdate(d, size),
                onPanEnd: _onPanEnd,
                child: Container(
                  color: const Color(0xFFE5E7EB),
                  child: Stack(
                    children: [
                      // วาด Grid ของ Tiles 3x3 รอบจุดศูนย์กลาง
                      for (int dx = -2; dx <= 2; dx++)
                        for (int dy = -2; dy <= 2; dy++) ...[
                          Positioned(
                            left: offsetX + dx * 256.0,
                            top: offsetY + dy * 256.0,
                            width: 256,
                            height: 256,
                            child: Image.network(
                              'https://tile.openstreetmap.org/$zoomLevel/${tileX + dx}/${tileY + dy}.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Center(
                                  child: Icon(
                                    Icons.map_outlined,
                                    color: Colors.grey,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                      // หมุด Google Maps ปักอยู่กึ่งกลางหน้าจอเสมอ
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, -26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      locationName,
                                      style: const TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (districtText.isNotEmpty)
                                      Text(
                                        'อ.$districtText จ.ปัตตานี',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Google Map Pin Icon
                              const Icon(
                                Icons.location_on,
                                size: 48,
                                color: Color(0xFFEA4335), // Google Maps Pin Red
                              ),
                              // Pin shadow on ground
                              Container(
                                width: 10,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. ปุ่มควบคุมซูม (+ / -) และปุ่มกลับจุดศูนย์กลางเมืองปัตตานี
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: kText,
                  onPressed: () {
                    if (zoomLevel < 17) {
                      setState(() => zoomLevel++);
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: kText,
                  onPressed: () {
                    if (zoomLevel > 11) {
                      setState(() => zoomLevel--);
                    }
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'recenter_pattani',
                  backgroundColor: Colors.white,
                  foregroundColor: kBlue,
                  tooltip: 'จุดศูนย์กลางเมืองปัตตานี',
                  onPressed: () {
                    setState(() {
                      currentLat = 6.8690;
                      currentLng = 101.2515;
                      zoomLevel = 14;
                      locationName = 'ตัวเมืองปัตตานี (หอนาฬิกา)';
                    });
                  },
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // 3. แถบเลือกสถานที่สำคัญด่วนด้านบน (Quick Place Chips)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.school, size: 16, color: kBlue),
                    label: const Text(
                      'ม.อ.ปัตตานี',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white,
                    onPressed: () => _selectPlace(kPattaniPlaces[0]),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.local_hospital,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'รพ.ปัตตานี',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white,
                    onPressed: () => _selectPlace(kPattaniPlaces[1]),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.mosque,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'มัสยิดกลาง',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white,
                    onPressed: () => _selectPlace(kPattaniPlaces[2]),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.beach_access,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'หาดตะโละกาโปร์',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white,
                    onPressed: () => _selectPlace(kPattaniPlaces[9]),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.temple_buddhist,
                      size: 16,
                      color: Colors.amber,
                    ),
                    label: const Text(
                      'วัดช้างให้',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.white,
                    onPressed: () => _selectPlace(kPattaniPlaces[12]),
                  ),
                ],
              ),
            ),
          ),

          // 4. แถบสรุปพิกัด/สถานที่ที่ปักหมุดแบบ Google Maps (มีชื่อหลัก, ที่อยู่ละเอียด, พิกัด, และปุ่มยืนยัน)
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFEA4335), // Google Red Pin
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'หมุดที่เลือก',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (isReverseGeocoding)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // ชื่อสถานที่หลัก
                            Text(
                              locationName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ที่อยู่ละเอียดสไตล์ Google Maps
                            Text(
                              detailedAddress,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4B5563),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // แถบแสดงพิกัดละติจูด/ลองจิจูด
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'พิกัด GPS: ${currentLat.toStringAsFixed(6)}, ${currentLng.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ปุ่มยืนยันตำแหน่ง
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // ส่งที่อยู่แบบละเอียดกลับไป (ชื่อสถานที่ + รายละเอียด)
                        final returnText =
                            detailedAddress.isNotEmpty &&
                                !detailedAddress.startsWith('กำลัง')
                            ? '$locationName, $detailedAddress'
                            : locationName;
                        Navigator.pop(context, returnText);
                      },
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        'เลือกตำแหน่งนี้',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8), // Google Blue
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Drawer สำหรับค้นหาและเลือกสถานที่สำคัญในปัตตานี
          if (showPlaceDrawer)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => showPlaceDrawer = false),
                child: Container(
                  color: Colors.black45,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'สถานที่สำคัญในปัตตานี',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => showPlaceDrawer = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'ค้นหาจุดสำคัญ, อำเภอ...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                filteredPlaces = kPattaniPlaces
                                    .where(
                                      (p) =>
                                          p.name.toLowerCase().contains(
                                            val.toLowerCase(),
                                          ) ||
                                          p.district.toLowerCase().contains(
                                            val.toLowerCase(),
                                          ),
                                    )
                                    .toList();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: filteredPlaces.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final p = filteredPlaces[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.location_on,
                                    color: kBlue,
                                    size: 20,
                                  ),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'อ.${p.district} • ${p.category}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => _selectPlace(p),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
