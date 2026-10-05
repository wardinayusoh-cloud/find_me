import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../admin/admin_home_page.dart';
import 'category_page.dart';
import 'chat_list_page.dart';
import '../shared/chat_room_page.dart';
import 'profile_page.dart';
import 'report_item_page.dart';
import 'notification_page.dart';
import '../shared/stat_banner_card.dart';
import '../auth/login_page.dart';
import 'item_detail_page.dart';

class HomePage extends StatefulWidget {
  final dynamic userData;

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ---------- สี ----------
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kTeal = Color(0xFF0F766E);
  static const Color kBg = Color(0xFFF4F7FE);
  static const Color kText = Color(0xFF1E293B);

  // ---------- state ----------
  late Map<String, dynamic> user; // ข้อมูลผู้ใช้

  int navIndex = 0; // 0=หน้าแรก 1=หมวดหมู่ 2=แชท 3=โปรไฟล์
  int tabIndex = 0; // 0=ทั้งหมด 1=ตามหาของ 2=ของที่พบ
  int profileRefresh = 0; // รีเฟรชสถานะโปรไฟล์
  int statRefresh = 0; // รีเฟรช StatBannerCard เมื่อมีการยืนยันคืนของ

  final TextEditingController searchController = TextEditingController();
  String keyword = '';
  Map<String, dynamic>? selectedCategory; // ตัวกรองหมวดหมู่
  String? selectedColor; // ตัวกรองสี
  String? selectedLocation; // ตัวกรองสถานที่
  String sortBy = 'newest'; // 'newest' | 'oldest'
  List<Map<String, dynamic>> categoriesList = [];

  bool isLoading = true;
  List<Map<String, dynamic>> items = [];
  final Set<String> bookmarked = {};

  @override
  void initState() {
    super.initState();
    user = widget.userData is Map
        ? Map<String, dynamic>.from(widget.userData)
        : <String, dynamic>{};
    _loadItems();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final res = await ApiService.getCategories();
    if (!mounted) return;
    if (res['success'] == true && res['data'] is List) {
      setState(() {
        categoriesList = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // LOAD ITEMS
  // =====================================================

  Future<void> _loadItems() async {
    // ปรับแก้ไข: เรียก API โดยไม่กรองเฉพาะ status: 'approved' เพื่อให้รายการที่เพิ่งส่งเรื่องขึ้นมาแสดงผลได้ด้วย
    final res = await ApiService.getItems();

    if (!mounted) return;

    setState(() {
      profileRefresh++;
      statRefresh++; // trigger ให้ StatBannerCard โหลดสถิติใหม่
      isLoading = false;
      if (res['success'] == true && res['data'] is List) {
        items = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

  int _count(String type) => items.where((e) {
    if (e['type'] != type) return false;
    final status = e['status']?.toString() ?? '';
    if (status == 'returned' || status == 'rejected') return false;
    // กรณีของหาย (lost) ไม่ต้องรอแอดมินอนุมัติ ให้แสดงได้เลย
    if (e['type'] != 'lost' && status == 'pending') return false;
    return true;
  }).length;

  void _goTab(int i) {
    setState(() {
      navIndex = i;
      if (i == 3) profileRefresh++;
    });
  }

  bool get hasActiveFilter =>
      selectedCategory != null ||
      selectedColor != null ||
      selectedLocation != null ||
      sortBy != 'newest';

  void _clearAllFilters() {
    setState(() {
      selectedCategory = null;
      selectedColor = null;
      selectedLocation = null;
      sortBy = 'newest';
    });
  }

  List<String> get availableLocations {
    final set = <String>{};
    for (final item in items) {
      final loc = item['location']?.toString().trim() ?? '';
      if (loc.isNotEmpty && loc != '-') {
        set.add(loc);
      }
    }
    return set.toList();
  }

  List<String> get availableColors {
    const defaultColors = [
      'ดำ',
      'ขาว',
      'แดง',
      'น้ำเงิน',
      'เขียว',
      'เหลือง',
      'ชมพู',
      'ส้ม',
      'เทา',
      'ม่วง',
      'น้ำตาล',
    ];
    final set = Set<String>.from(defaultColors);
    for (final item in items) {
      final c = item['color']?.toString().trim() ?? '';
      if (c.isNotEmpty && c != '-') {
        set.add(c);
      }
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get filteredItems {
    final list = items.where((e) {
      // ซ่อนรายการที่คืนเจ้าของสำเร็จแล้ว หรือถูกปฏิเสธ
      final status = e['status']?.toString() ?? '';
      if (status == 'returned' || status == 'rejected') {
        return false;
      }
      // กรณีของหาย (lost) ไม่ต้องรอแอดมินอนุมัติ สามารถแสดงได้ทันที ส่วนของพบ (found) ยังต้องรอ approved
      if (e['type'] != 'lost' && status == 'pending') {
        return false;
      }

      if (tabIndex == 1 && e['type'] != 'lost') return false;
      if (tabIndex == 2 && e['type'] != 'found') return false;

      // กรองหมวดหมู่
      if (selectedCategory != null) {
        final catId = e['category_id']?.toString() ?? '';
        final catName = e['category_name']?.toString() ?? '';
        final targetId = selectedCategory!['id']?.toString() ?? '';
        final targetName = selectedCategory!['name']?.toString() ?? '';
        if (catId != targetId && catName != targetName) {
          return false;
        }
      }

      // กรองสี
      if (selectedColor != null && selectedColor!.isNotEmpty) {
        final itemColor = e['color']?.toString().toLowerCase() ?? '';
        if (!itemColor.contains(selectedColor!.toLowerCase())) {
          return false;
        }
      }

      // กรองสถานที่
      if (selectedLocation != null && selectedLocation!.isNotEmpty) {
        final itemLoc = e['location']?.toString().toLowerCase() ?? '';
        if (!itemLoc.contains(selectedLocation!.toLowerCase())) {
          return false;
        }
      }

      // ค้นหาข้อความ
      if (keyword.isNotEmpty) {
        final text = [
          e['item_name'],
          e['description'],
          e['location'],
          e['color'],
          e['category_name'],
        ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
        if (!text.contains(keyword.toLowerCase())) return false;
      }
      return true;
    }).toList();

    // จัดเรียง
    if (sortBy == 'oldest') {
      list.sort((a, b) {
        final da =
            DateTime.tryParse(
              a['lost_found_date']?.toString() ??
                  a['created_at']?.toString() ??
                  '',
            ) ??
            DateTime(1970);
        final db =
            DateTime.tryParse(
              b['lost_found_date']?.toString() ??
                  b['created_at']?.toString() ??
                  '',
            ) ??
            DateTime(1970);
        return da.compareTo(db);
      });
    } else {
      list.sort((a, b) {
        final da =
            DateTime.tryParse(
              a['lost_found_date']?.toString() ??
                  a['created_at']?.toString() ??
                  '',
            ) ??
            DateTime(1970);
        final db =
            DateTime.tryParse(
              b['lost_found_date']?.toString() ??
                  b['created_at']?.toString() ??
                  '',
            ) ??
            DateTime(1970);
        return db.compareTo(da);
      });
    }

    return list;
  }

  // =====================================================
  // HELPERS
  // =====================================================

  String get _fullName =>
      user['full_name']?.toString() ?? user['username']?.toString() ?? 'U';

  String _initial(String? name) =>
      (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'U';

  String _firstImage(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '';
    final first = s.split(',').first.trim();
    return ApiService.imageUrl(first);
  }

  String _formatDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year + 543}';
  }

  void _toast(String msg, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _openReport(bool asFound) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportItemPage(userData: user, startAsFound: asFound),
      ),
    );
    _loadItems();
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEDD5),
                  child: Icon(Icons.report_problem, color: Colors.orange),
                ),
                title: const Text('แจ้งของหาย'),
                subtitle: const Text('ฉันทำของหาย ต้องการตามหา'),
                onTap: () {
                  Navigator.pop(context);
                  _openReport(false);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.inventory_2, color: Colors.green),
                ),
                title: const Text('แจ้งพบของ'),
                subtitle: const Text('ฉันเจอของ อยากคืนเจ้าของ'),
                onTap: () {
                  Navigator.pop(context);
                  _openReport(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // CLAIM
  // =====================================================

  Future<void> _claimItem(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    XFile? selectedImage;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('ยื่นสิทธิ์ความเป็นเจ้าของ'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- ช่องอัพโหลดรูปภาพ ----------
                    const Text(
                      'รูปภาพหลักฐาน *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ถ่ายรูปของคุณเพื่อยืนยันว่าเป็นเจ้าของ',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final source = await showModalBottomSheet<ImageSource>(
                          context: dialogContext,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.camera_alt,
                                    color: Color(0xFF2563EB),
                                  ),
                                  title: const Text('ถ่ายรูป'),
                                  onTap: () =>
                                      Navigator.pop(ctx, ImageSource.camera),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.photo_library,
                                    color: Color(0xFF2563EB),
                                  ),
                                  title: const Text('เลือกจากแกลเลอรี'),
                                  onTap: () =>
                                      Navigator.pop(ctx, ImageSource.gallery),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (source == null) return;
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: source,
                          imageQuality: 80,
                          maxWidth: 1024,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedImage = picked);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedImage != null
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFCBD5E1),
                            width: selectedImage != null ? 2 : 1,
                          ),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: kIsWeb
                                    ? Image.network(
                                        selectedImage!.path,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 120,
                                      )
                                    : Image.file(
                                        File(selectedImage!.path),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 120,
                                      ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'แตะเพื่อเลือกรูปภาพ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (selectedImage != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              setDialogState(() => selectedImage = null),
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'ลบรูป',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // ---------- ช่องรายละเอียด ----------
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'อธิบายลักษณะเฉพาะของสิ่งของ\nเพื่อยืนยันว่าเป็นของคุณ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, {
                    'description': controller.text.trim(),
                    'image': selectedImage,
                  });
                },
                child: const Text('ส่งคำขอ'),
              ),
            ],
          );
        },
      ),
    );

    // dispose หลังจากอ่านค่าแล้ว และให้แน่ใจว่า dialog unmount เรียบร้อยก่อน
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null) return;

    final description = result['description'] as String? ?? '';
    final image = result['image'] as XFile?;

    if (image == null) {
      _toast('กรุณาถ่ายรูปหรือเลือกรูปภาพหลักฐาน', color: Colors.red);
      return;
    }

    if (description.isEmpty) {
      _toast(
        'กรุณากรอกรายละเอียดเพื่อยืนยันความเป็นเจ้าของ',
        color: Colors.red,
      );
      return;
    }

    // อัพโหลดรูปภาพก่อน
    _toast('กำลังอัพโหลดรูปภาพ...', color: kBlue);
    final uploadRes = await ApiService.uploadImage(image);
    if (!mounted) return;

    String evidenceImageUrl = '';
    if (uploadRes['success'] == true && uploadRes['data'] != null) {
      evidenceImageUrl = uploadRes['data']['url']?.toString() ?? '';
    } else {
      _toast(
        uploadRes['message']?.toString() ?? 'อัพโหลดรูปภาพไม่สำเร็จ',
        color: Colors.red,
      );
      return;
    }

    final res = await ApiService.claim(
      itemId: int.tryParse(item['id'].toString()) ?? 0,
      userId: int.tryParse(user['id']?.toString() ?? '') ?? 0,
      description: description,
      evidenceImage: evidenceImageUrl,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      _toast('ส่งคำขอรับของแล้ว', color: Colors.green);

      // สอบถามผู้ใช้ว่าต้องการเปิดห้องแชทคุยกับเจ้าหน้าที่/แอดมินเกี่ยวกับรายการนี้เลยหรือไม่
      final openChat = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.forum_outlined, color: kBlue),
              SizedBox(width: 8),
              Text('เปิดห้องแชททันที?'),
            ],
          ),
          content: Text(
            'ส่งคำขอยื่นสิทธิ์สำหรับ "${item['item_name'] ?? 'สิ่งของ'}" สำเร็จแล้ว ระบบได้ส่งการแจ้งเตือนไปยังผู้แจ้งแล้ว\nต้องการเปิดห้องแชทคุยกับผู้แจ้งทันทีหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ไว้ทีหลัง'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('เปิดแชทเลย'),
            ),
          ],
        ),
      );

      // โหลดรายการใหม่หลังจาก dialog ทั้งหมดปิดแล้ว เพื่อป้องกัน setState conflict
      if (mounted) _loadItems();

      if (openChat == true && mounted) {
        _chatAboutItem(item);
      }
    } else {
      _toast(
        res['message']?.toString() ?? 'ส่งคำขอไม่สำเร็จ',
        color: Colors.red,
      );
    }
  }

  /// เปิดห้องแชทนัดรับของ / คุยกับผู้แจ้งรายการนี้โดยตรง
  Future<void> _chatAboutItem(Map<String, dynamic> item) async {
    final currentUserId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
    if (currentUserId <= 0) {
      _toast('กรุณาเข้าสู่ระบบก่อนเริ่มแชท', color: Colors.red);
      return;
    }

    final reporterId = int.tryParse(item['user_id']?.toString() ?? '') ?? 0;
    if (reporterId == currentUserId) {
      _toast('คุณเป็นผู้แจ้งรายการนี้', color: Colors.orange);
      return;
    }

    _toast('กำลังเปิดห้องแชท...');

    final itemId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
    final res = await ApiService.openItemChat(
      itemId: itemId,
      userId: currentUserId,
    );

    if (!mounted) return;

    if (res['success'] != true || res['data'] == null) {
      _toast(
        res['message']?.toString() ?? 'เปิดห้องแชทไม่สำเร็จ',
        color: Colors.red,
      );
      return;
    }

    final data = res['data'];
    final itemChatId = int.tryParse(data['item_chat_id'].toString()) ?? 0;
    final peerName = data['peer_name']?.toString() ?? 'ผู้แจ้ง';
    final itemName = data['item_name']?.toString() ?? item['item_name'] ?? '';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          conversationId: itemChatId,
          currentUserId: currentUserId,
          title: peerName,
          subtitle: 'นัดรับของ: $itemName',
          isPeerChat: true,
        ),
      ),
    );
  }

  // =====================================================
  // REPORT FOUND FOR LOST ITEM – "ฉันเจอของชิ้นนี้"
  // เปิดแชทตามปกติ + ส่งแจ้งเตือนไปยังเจ้าของในเบื้องหลัง
  // =====================================================

  Future<void> _openFoundReportForLostItem(Map<String, dynamic> item) async {
    final currentUserId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
    if (currentUserId <= 0) {
      _toast('กรุณาเข้าสู่ระบบก่อน', color: Colors.red);
      return;
    }

    final ownerId = int.tryParse(item['user_id']?.toString() ?? '') ?? 0;
    if (ownerId == currentUserId) {
      _toast('คุณเป็นเจ้าของรายการนี้', color: Colors.orange);
      return;
    }

    final itemId = int.tryParse(item['id']?.toString() ?? '') ?? 0;

    // ส่งแจ้งเตือนไปหาเจ้าของในเบื้องหลัง (silent)
    ApiService.reportFound(
      lostItemId: itemId,
      finderId: currentUserId,
      location: item['location']?.toString() ?? '',
    );

    // ยื่น claim อัตโนมัติก่อน (openItemChat ต้องการ claim)
    // ถ้ามี claim อยู่แล้วระบบจะ ignore (API จะคืน error แต่แชทยังเปิดได้)
    await ApiService.claim(
      itemId: itemId,
      userId: currentUserId,
      description: 'แจ้งว่าพบของชิ้นนี้',
    );

    if (!mounted) return;

    // เปิดแชทกับเจ้าของตามปกติ
    _chatAboutItem(item);
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            if (navIndex != 2) _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: navIndex,
                children: [
                  _buildHomeTab(),
                  CategoryPage(
                    items: items,
                    onSelect: (category) {
                      setState(() {
                        selectedCategory = category;
                        tabIndex = 0;
                        navIndex = 0;
                      });
                    },
                    onSearch: (k) {
                      setState(() {
                        keyword = k;
                        searchController.text = k;
                        selectedCategory = null;
                        tabIndex = 0;
                        navIndex = 0;
                      });
                    },
                  ),
                  ChatListPage(
                    userId: int.tryParse(user['id']?.toString() ?? '') ?? 0,
                  ),
                  ProfilePage(
                    userData: user,
                    onUpdated: (newUser) => setState(() => user = newUser),
                    refreshToken: profileRefresh,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        onPressed: _showReportSheet,
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // =====================================================
  // HOME TAB
  // =====================================================

  Widget _buildHomeTab() {
    final list = filteredItems;

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildSearchBar(),
          const SizedBox(height: 14),
          StatBannerCard(refreshTrigger: statRefresh),
          const SizedBox(height: 14),
          _buildTabs(),
          if (hasActiveFilter) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (selectedCategory != null) ...[
                    InputChip(
                      avatar: const Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: kBlue,
                      ),
                      label: Text('หมวด: ${selectedCategory!['name']}'),
                      onDeleted: () => setState(() => selectedCategory = null),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: kBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      deleteIconColor: kBlue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (selectedColor != null) ...[
                    InputChip(
                      avatar: const Icon(
                        Icons.palette_outlined,
                        size: 16,
                        color: kBlue,
                      ),
                      label: Text('สี: $selectedColor'),
                      onDeleted: () => setState(() => selectedColor = null),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: kBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      deleteIconColor: kBlue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (selectedLocation != null) ...[
                    InputChip(
                      avatar: const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: kBlue,
                      ),
                      label: Text('สถานที่: $selectedLocation'),
                      onDeleted: () => setState(() => selectedLocation = null),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: kBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      deleteIconColor: kBlue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (sortBy != 'newest') ...[
                    InputChip(
                      avatar: const Icon(Icons.sort, size: 16, color: kBlue),
                      label: const Text('เรียง: เก่าสุดก่อน'),
                      onDeleted: () => setState(() => sortBy = 'newest'),
                      backgroundColor: const Color(0xFFDBEAFE),
                      labelStyle: const TextStyle(
                        color: kBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      deleteIconColor: kBlue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  TextButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(
                      Icons.clear_all,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'ล้างทั้งหมด',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            _buildEmpty()
          else
            ...list.map(_buildItemCard),
        ],
      ),
    );
  }

  // ---------- AVATAR ----------
  Widget _avatar(double radius) {
    final url = ApiService.imageUrl(user['avatar_url']?.toString() ?? '');

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDBEAFE),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              _initial(_fullName),
              style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  // ---------- HEADER ----------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.find_in_page, color: kBlue, size: 24),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FindMe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kBlue,
                  height: 1.1,
                ),
              ),
              Text(
                const ['Home', 'Categories', 'Chat', 'Profile'][navIndex],
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBlue.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on, color: kBlue, size: 16),
                SizedBox(width: 4),
                Text(
                  'ปัตตานี',
                  style: TextStyle(
                    color: kBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (user['role'] == 'admin') ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminHomePage(userData: user),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: Colors.amber,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              final uid = int.tryParse(user['id']?.toString() ?? '') ?? 0;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationPage(userId: uid),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none, color: kText, size: 22),
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            tooltip: 'บัญชีผู้ใช้',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                _goTab(3);
              } else if (value == 'logout') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('ออกจากระบบ'),
                    content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'ออกจากระบบ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20, color: kBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'ดูโปรไฟล์ของฉัน',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Text(
                      'ออกจากระบบ',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: _avatar(19),
          ),
        ],
      ),
    );
  }

  // ---------- SEARCH ----------
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (v) => setState(() => keyword = v.trim()),
        decoration: InputDecoration(
          hintText: 'ค้นหาของหาย เช่น กระเป๋า, iPad, กุญแจ...',
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.tune, color: hasActiveFilter ? kBlue : kText),
                if (hasActiveFilter)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'ตัวกรอง',
            onPressed: _showFilterSheet,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ---------- FILTER SHEET ----------
  void _showFilterSheet() {
    Map<String, dynamic>? tempCategory = selectedCategory;
    String? tempColor = selectedColor;
    String? tempLocation = selectedLocation;
    String tempSortBy = sortBy;

    // รวบรวม categories จาก API หรือจาก items
    final cats = List<Map<String, dynamic>>.from(categoriesList);
    if (cats.isEmpty) {
      final seen = <String>{};
      for (final it in items) {
        final name = it['category_name']?.toString() ?? '';
        final id = it['category_id']?.toString() ?? '';
        if (name.isNotEmpty && !seen.contains(name)) {
          seen.add(name);
          cats.add({'id': id, 'name': name});
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final locs = availableLocations;
            final colors = availableColors;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // แถบจับด้านบน
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune, color: kBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ตัวกรองการค้นหา',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kText,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempCategory = null;
                              tempColor = null;
                              tempLocation = null;
                              tempSortBy = 'newest';
                            });
                          },
                          child: const Text(
                            'ล้างทั้งหมด',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // เนื้อหาตัวกรอง
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. หมวดหมู่
                          const Text(
                            'หมวดหมู่',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('ทั้งหมด'),
                                selected: tempCategory == null,
                                selectedColor: const Color(0xFFDBEAFE),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: tempCategory == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: tempCategory == null ? kBlue : kText,
                                ),
                                onSelected: (val) {
                                  if (val)
                                    setSheetState(() => tempCategory = null);
                                },
                              ),
                              ...cats.map((cat) {
                                final isSel =
                                    tempCategory != null &&
                                    (tempCategory!['id']?.toString() ==
                                            cat['id']?.toString() ||
                                        tempCategory!['name'] == cat['name']);
                                return ChoiceChip(
                                  label: Text(cat['name']?.toString() ?? ''),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFDBEAFE),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSel ? kBlue : kText,
                                  ),
                                  onSelected: (val) {
                                    setSheetState(
                                      () => tempCategory = val ? cat : null,
                                    );
                                  },
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 2. การเรียงลำดับ
                          const Text(
                            'เรียงลำดับตามวันที่',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  avatar: Icon(
                                    Icons.arrow_downward,
                                    size: 16,
                                    color: tempSortBy == 'newest'
                                        ? kBlue
                                        : Colors.grey,
                                  ),
                                  label: const Center(
                                    child: Text('ล่าสุดก่อน'),
                                  ),
                                  selected: tempSortBy == 'newest',
                                  selectedColor: const Color(0xFFDBEAFE),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: tempSortBy == 'newest'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: tempSortBy == 'newest'
                                        ? kBlue
                                        : kText,
                                  ),
                                  onSelected: (val) {
                                    if (val)
                                      setSheetState(
                                        () => tempSortBy = 'newest',
                                      );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  avatar: Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                    color: tempSortBy == 'oldest'
                                        ? kBlue
                                        : Colors.grey,
                                  ),
                                  label: const Center(
                                    child: Text('เก่าสุดก่อน'),
                                  ),
                                  selected: tempSortBy == 'oldest',
                                  selectedColor: const Color(0xFFDBEAFE),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: tempSortBy == 'oldest'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: tempSortBy == 'oldest'
                                        ? kBlue
                                        : kText,
                                  ),
                                  onSelected: (val) {
                                    if (val)
                                      setSheetState(
                                        () => tempSortBy = 'oldest',
                                      );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 3. สีของสิ่งของ
                          const Text(
                            'สีของสิ่งของ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('ทุกสี'),
                                selected: tempColor == null,
                                selectedColor: const Color(0xFFDBEAFE),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: tempColor == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: tempColor == null ? kBlue : kText,
                                ),
                                onSelected: (val) {
                                  if (val)
                                    setSheetState(() => tempColor = null);
                                },
                              ),
                              ...colors.map((c) {
                                final isSel = tempColor == c;
                                return ChoiceChip(
                                  label: Text(c),
                                  selected: isSel,
                                  selectedColor: const Color(0xFFDBEAFE),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSel ? kBlue : kText,
                                  ),
                                  onSelected: (val) {
                                    setSheetState(
                                      () => tempColor = val ? c : null,
                                    );
                                  },
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 4. สถานที่
                          if (locs.isNotEmpty) ...[
                            const Text(
                              'สถานที่พบ/หาย',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: kText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('ทุกสถานที่'),
                                  selected: tempLocation == null,
                                  selectedColor: const Color(0xFFDBEAFE),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: tempLocation == null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: tempLocation == null ? kBlue : kText,
                                  ),
                                  onSelected: (val) {
                                    if (val)
                                      setSheetState(() => tempLocation = null);
                                  },
                                ),
                                ...locs.map((loc) {
                                  final isSel = tempLocation == loc;
                                  return ChoiceChip(
                                    avatar: Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: isSel ? kBlue : Colors.grey,
                                    ),
                                    label: Text(loc),
                                    selected: isSel,
                                    selectedColor: const Color(0xFFDBEAFE),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSel ? kBlue : kText,
                                    ),
                                    onSelected: (val) {
                                      setSheetState(
                                        () => tempLocation = val ? loc : null,
                                      );
                                    },
                                  );
                                }),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ปุ่มบันทึก/ใช้ตัวกรอง
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedCategory = tempCategory;
                            selectedColor = tempColor;
                            selectedLocation = tempLocation;
                            sortBy = tempSortBy;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'ใช้ตัวกรอง',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------- TABS ----------
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tab(0, Icons.grid_view_rounded, 'ทั้งหมด', null, Colors.transparent),
          _tab(
            1,
            Icons.radar,
            'ตามหาของ',
            _count('lost'),
            const Color(0xFFFED7AA),
          ),
          _tab(
            2,
            Icons.verified_outlined,
            'ของที่พบ',
            _count('found'),
            const Color(0xFFBBF7D0),
          ),
        ],
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label, int? count, Color badge) {
    final selected = tabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kBlue.withOpacity(0.25) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? kBlue : kText),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: selected ? kBlue : kText,
                  ),
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: badge,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- EMPTY ----------
  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text('ยังไม่มีรายการ', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ---------- ITEM CARD ----------
  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isFoundItem = item['type'] == 'found';
    final Color typeColor = isFoundItem ? kTeal : Colors.orange.shade700;
    final String id = item['id'].toString();
    final String imageUrl = _firstImage(item['image_url']);
    final String reporter = item['full_name']?.toString() ?? '-';
    final bool saved = bookmarked.contains(id);
    final String myId = (user['id'] ?? '').toString();
    final String ownerId = (item['user_id'] ?? '').toString();
    final bool isOwner = myId.isNotEmpty && myId == ownerId;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ItemDetailPage(item: item, currentUser: widget.userData),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: imageUrl.isEmpty
                              ? _imagePlaceholder()
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFoundItem ? Icons.check_circle : Icons.search,
                                color: Colors.white,
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isFoundItem ? 'พบของ' : 'ของหาย',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item['item_name']?.toString() ?? '-',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: kText,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                saved
                                    ? bookmarked.remove(id)
                                    : bookmarked.add(id);
                              }),
                              child: Icon(
                                saved ? Icons.bookmark : Icons.bookmark_border,
                                color: saved ? kBlue : Colors.grey,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _infoLine(
                          Icons.location_on_outlined,
                          item['location']?.toString() ?? '-',
                          bold: true,
                        ),
                        const SizedBox(height: 3),
                        _infoLine(
                          Icons.access_time,
                          _formatDate(item['lost_found_date']),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: typeColor,
                    child: Text(
                      _initial(reporter),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reporter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: kText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isOwner) ...[
                    IconButton(
                      tooltip: isFoundItem
                          ? 'ติดต่อสอบถาม/แชทเรื่องนี้'
                          : 'ติดต่อเจ้าของ/แชท',
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: kBlue,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                        ),
                      ),
                      onPressed: () => _chatAboutItem(item),
                    ),
                    const SizedBox(width: 8),
                    isFoundItem
                        ? ElevatedButton.icon(
                            onPressed: () => _claimItem(item),
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text(
                              'ยื่นสิทธิ์ความเป็นเจ้าของ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _openFoundReportForLostItem(item),
                            icon: const Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'ฉันเจอของชิ้นนี้',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kTeal,
                              side: const BorderSide(color: kTeal),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Text(
                        'รายการของคุณ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  Widget _infoLine(IconData icon, String text, {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // BOTTOM BAR
  // =====================================================

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 68,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _navItem(0, Icons.home_rounded, 'หน้าแรก'),
          _navItem(1, Icons.grid_view_rounded, 'หมวดหมู่'),
          const Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'แจ้งเรื่อง',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),
          ),
          _navItem(2, Icons.chat_bubble_outline, 'แชท'),
          _navItem(3, Icons.person_outline, 'โปรไฟล์'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = navIndex == index;
    final color = selected ? kBlue : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () => _goTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
