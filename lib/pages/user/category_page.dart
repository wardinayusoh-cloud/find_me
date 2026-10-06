import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../shared/stat_banner_card.dart';

/// หน้า "เลือกตามประเภทของหาย"
/// - ดึงหมวดหมู่จาก API (action=categories)
/// - นับจำนวนรายการในแต่ละหมวดจาก [items] ที่ HomePage โหลดไว้แล้ว
class CategoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onSelect; // กดการ์ดหมวดหมู่
  final ValueChanged<String> onSearch; // กด Enter ในช่องค้นหา

  const CategoryPage({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onSearch,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);

  // สีประจำการ์ด (วนใช้ตามลำดับ)
  static const List<Color> palette = [
    Color(0xFF2563EB), // น้ำเงิน
    Color(0xFFDC2626), // แดง
    Color(0xFFEA580C), // ส้ม
    Color(0xFF0F766E), // เขียวเทา
    Color(0xFF7C3AED), // ม่วง
    Color(0xFFDB2777), // ชมพู
    Color(0xFF16A34A), // เขียว
    Color(0xFF4F46E5), // คราม
  ];

  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  String keyword = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getCategories();

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (res['success'] == true && res['data'] is List) {
        categories = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

  int _countOf(dynamic id, {String? type}) {
    return widget.items.where((e) {
      if (e['category_id'].toString() != id.toString()) return false;
      if (type != null && e['type'] != type) return false;
      final status = e['status']?.toString() ?? '';
      if (status == 'returned' || status == 'rejected') {
        return false;
      }
      if (e['type'] != 'lost' && status == 'pending') {
        return false;
      }
      return true;
    }).length;
  }

  // เลือกไอคอนจากคำในชื่อหมวดหมู่
  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    bool has(List<String> keys) => keys.any((k) => n.contains(k));

    if (has(['มือถือ', 'โทรศัพท์', 'phone', 'gadget', 'อิเล็กทรอนิกส์'])) {
      return Icons.smartphone;
    }
    if (has(['สตางค์', 'wallet', 'เงิน'])) return Icons.account_balance_wallet;
    if (has(['บัตร', 'เอกสาร', 'card', 'document'])) return Icons.badge;
    if (has(['สัตว์', 'pet'])) return Icons.pets;
    if (has(['นาฬิกา', 'เครื่องประดับ', 'watch', 'jewel'])) return Icons.watch;
    if (has(['กุญแจ', 'key'])) return Icons.vpn_key;
    if (has(['กระเป๋า', 'bag'])) return Icons.shopping_bag_outlined;
    if (has(['เสื้อ', 'cloth'])) return Icons.checkroom;
    if (has(['เครื่องเขียน', 'หนังสือ', 'book', 'stationery'])) {
      return Icons.edit;
    }
    return Icons.category_outlined;
  }

  List<Map<String, dynamic>> get filtered {
    if (keyword.isEmpty) return categories;
    return categories
        .where((c) => (c['name']?.toString().toLowerCase() ?? '')
            .contains(keyword.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ---------- ค้นหา ----------
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
              ],
            ),
            child: TextField(
              onChanged: (v) => setState(() => keyword = v.trim()),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) widget.onSearch(v.trim());
              },
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'ค้นหาหมวดหมู่ หรือชื่อสิ่งของที่หาย...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 14),
          const StatBannerCard(),
          const SizedBox(height: 18),

          // ---------- หัวข้อ ----------
          Row(
            children: [
              const Text(
                'เลือกตามประเภทของหาย',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${categories.length} หมวด',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('ไม่พบหมวดหมู่',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 152,
              ),
              itemBuilder: (_, i) => _buildCard(list[i], i),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> c, int index) {
    final Color color = palette[index % palette.length];
    final String name = c['name']?.toString() ?? '-';
    final String subtitle =
        c['name_en']?.toString() ?? c['description']?.toString() ?? '';

    final int total = _countOf(c['id']);
    final int found = _countOf(c['id'], type: 'found');
    final int lost = _countOf(c['id'], type: 'lost');

    final bool showFound = found > 0;
    final String chipText = showFound
        ? 'พบแล้ว +$found'
        : (lost > 0 ? 'ตามหา $lost' : 'ยังไม่มีรายการ');
    final IconData chipIcon =
        showFound ? Icons.check_circle_outline : Icons.search;

    return InkWell(
      onTap: () => widget.onSelect(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFor(name), color: color, size: 22),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(chipIcon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      chipText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}