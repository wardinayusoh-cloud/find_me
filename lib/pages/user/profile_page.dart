import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../admin/admin_home_page.dart';
import 'report_item_page.dart';
import 'status_page.dart';

class ProfilePage extends StatefulWidget {
  final dynamic userData;

  /// เรียกทุกครั้งที่บันทึกข้อมูล/เปลี่ยนรูปสำเร็จ เพื่อให้ HomePage อัปเดตตาม
  final ValueChanged<Map<String, dynamic>>? onUpdated;

  /// เปลี่ยนค่านี้จากภายนอก (เช่นทุกครั้งที่แตะแท็บโปรไฟล์) เพื่อสั่งให้
  /// หน้านี้โหลดสถิติ/สถานะล่าสุดใหม่โดยไม่ต้องสลับหน้า
  final int refreshToken;

  const ProfilePage({
    super.key,
    this.userData,
    this.onUpdated,
    this.refreshToken = 0,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);
  static const Color kGrey = Color(0xFF64748B);

  final ImagePicker _picker = ImagePicker();

  late Map<String, dynamic> user;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  bool editing = false;
  bool saving = false;
  bool uploadingAvatar = false;
  Uint8List? localAvatar; // รูปที่เพิ่งเลือก (โชว์ทันทีระหว่างอัปโหลด)

  // ---------- สถิติของฉัน (คำนวณจาก my_items / my_claims) ----------
  bool loadingStats = true;
  int reportedCount = 0; // รายการที่แจ้งทั้งหมด
  int inProgressCount = 0; // pending + approved + claimed
  int returnedCount = 0; // returned สำเร็จ

  // ---------- รายการของฉัน (แก้ไข / ลบ) ----------
  List<Map<String, dynamic>> myItems = [];
  int? deletingId;

  @override
  void initState() {
    super.initState();
    user = _toMap(widget.userData);
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData != oldWidget.userData && !editing) {
      user = _toMap(widget.userData);
    }
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadStats();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _toMap(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

  // =====================================================
  // GETTERS
  // =====================================================

  String get _name => user['full_name']?.toString().trim().isNotEmpty == true
      ? user['full_name'].toString()
      : (user['name']?.toString() ?? 'ไม่ระบุชื่อ');

  String get _username => user['username']?.toString() ?? '-';
  String get _email => user['email']?.toString() ?? '';
  String get _phone => user['phone']?.toString() ?? '';
  String get _role => user['role']?.toString() ?? 'user';
  String get _avatarUrl => ApiService.imageUrl(user['avatar_url']?.toString() ?? '');
  int get _userId => int.tryParse(user['id']?.toString() ?? '') ?? 0;


  void _toast(String msg, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _applyUser(dynamic data) {
    setState(() => user = _toMap(data));
    widget.onUpdated?.call(user);
  }

  // =====================================================
  // โหลดสถิติของฉันจาก my_items
  // =====================================================

  Future<void> _loadStats() async {
    if (_userId <= 0) {
      setState(() => loadingStats = false);
      return;
    }

    setState(() => loadingStats = true);

    final res = await ApiService.getMyItems(_userId);

    if (!mounted) return;

    if (res['success'] == true && res['data'] is List) {
      final list = (res['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        reportedCount = list.length;
        inProgressCount = list
            .where(
              (e) => ['pending', 'approved', 'claimed'].contains(e['status']),
            )
            .length;
        returnedCount = list.where((e) => e['status'] == 'returned').length;
        myItems = list;
        loadingStats = false;
      });
    } else {
      setState(() => loadingStats = false);
    }
  }

  // =====================================================
  // เปลี่ยนรูปโปรไฟล์
  // =====================================================

  void _showAvatarSheet() {
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
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกจากแกลเลอรี'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูป'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        localAvatar = bytes;
        uploadingAvatar = true;
      });

      // 1) อัปโหลดรูป
      final up = await ApiService.uploadImage(picked);

      if (!mounted) return;

      final url = (up['data'] is Map) ? up['data']['url']?.toString() : null;

      if (up['success'] != true || url == null || url.isEmpty) {
        setState(() {
          localAvatar = null;
          uploadingAvatar = false;
        });
        _toast(
          up['message']?.toString() ?? 'อัปโหลดรูปไม่สำเร็จ',
          color: Colors.red,
        );
        return;
      }

      // 2) บันทึก URL รูปลงโปรไฟล์
      final res = await ApiService.updateProfile(
        userId: _userId,
        fullName: _name,
        email: _email,
        phone: _phone,
        avatarUrl: url,
      );

      if (!mounted) return;

      setState(() => uploadingAvatar = false);

      if (res['success'] == true) {
        _applyUser(res['data']);
        _toast('เปลี่ยนรูปโปรไฟล์สำเร็จ', color: Colors.green);
      } else {
        setState(() => localAvatar = null);
        _toast(
          res['message']?.toString() ?? 'บันทึกรูปไม่สำเร็จ',
          color: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        localAvatar = null;
        uploadingAvatar = false;
      });
      _toast('ไม่สามารถเลือกรูปได้: $e', color: Colors.red);
    }
  }

  // =====================================================
  // แก้ไขข้อมูล
  // =====================================================

  void _startEdit() {
    nameController.text = _name == 'ไม่ระบุชื่อ' ? '' : _name;
    emailController.text = _email;
    phoneController.text = _phone;
    setState(() => editing = true);
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      _toast('กรุณากรอกชื่อ-นามสกุล', color: Colors.red);
      return;
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _toast('รูปแบบอีเมลไม่ถูกต้อง', color: Colors.red);
      return;
    }

    if (phone.isNotEmpty && phone.length < 9) {
      _toast('เบอร์โทรศัพท์ไม่ถูกต้อง', color: Colors.red);
      return;
    }

    setState(() => saving = true);

    final res = await ApiService.updateProfile(
      userId: _userId,
      fullName: name,
      email: email,
      phone: phone,
    );

    if (!mounted) return;

    setState(() => saving = false);

    if (res['success'] == true) {
      _applyUser(res['data']);
      setState(() => editing = false);
      _toast('บันทึกข้อมูลสำเร็จ', color: Colors.green);
    } else {
      _toast(
        res['message']?.toString() ?? 'บันทึกข้อมูลไม่สำเร็จ',
        color: Colors.red,
      );
    }
  }


  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 14),
              _buildStatusEntry(),
              if (_role.toLowerCase() == 'admin') ...[
                const SizedBox(height: 14),
                _buildAdminEntry(),
              ],
              const SizedBox(height: 14),
              _buildInfoCard(),
              const SizedBox(height: 14),
              _buildMyItemsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- การ์ดรูป + ชื่อ + สถิติสั้นๆ ----------
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 70,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: _buildAvatar(),
              ),

            ],
          ),
          const SizedBox(height: 10),
          Text(
            _name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _email.isNotEmpty ? _email : '@$_username',
            style: const TextStyle(color: kGrey, fontSize: 12.5),
          ),
          const SizedBox(height: 10),

          // ชิปจังหวัด
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _chip(
                Icons.location_on_outlined,
                'จังหวัดของคุณ: ปัตตานี',
                kBlue,
              ),
            ],
          ),

          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: uploadingAvatar ? null : _showAvatarSheet,
            icon: const Icon(Icons.photo_camera_outlined, size: 16),
            label: const Text(
              'เปลี่ยนรูปโปรไฟล์',
              style: TextStyle(fontSize: 12),
            ),
          ),

          const Divider(height: 1),

          // แถวสถิติ 3 ช่อง
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: loadingStats
                ? const SizedBox(
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      _statCell('$reportedCount', 'รายการที่แจ้ง'),
                      _vDivider(),
                      _statCell('$inProgressCount', 'กำลังดำเนินการ'),
                      _vDivider(),
                      _statCell('$returnedCount', 'คืนสำเร็จ'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 30, color: const Color(0xFFE2E8F0));

  Widget _statCell(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: kGrey),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: uploadingAvatar ? null : _showAvatarSheet,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: SizedBox(
                width: 80,
                height: 80,
                child: localAvatar != null
                    ? Image.memory(localAvatar!, fit: BoxFit.cover)
                    : (_avatarUrl.isNotEmpty
                        ? Image.network(
                            _avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackAvatarText(),
                          )
                        : _fallbackAvatarText()),
              ),
            ),
          ),
          if (uploadingAvatar)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatarText() {
    return Container(
      color: const Color(0xFFDBEAFE),
      alignment: Alignment.center,
      child: Text(
        _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: kBlue,
        ),
      ),
    );
  }

  // =====================================================
  // รายการของฉัน (แก้ไข / ลบ)
  // =====================================================

  static const Map<String, String> _statusLabel = {
    'pending': 'รอตรวจสอบ',
    'approved': 'อนุมัติแล้ว',
    'rejected': 'ไม่อนุมัติ',
    'claimed': 'มีผู้ขอรับ',
    'returned': 'คืนแล้ว',
  };

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'claimed':
        return const Color(0xFFEA580C);
      case 'returned':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFFD97706); // pending
    }
  }

  int _itemId(Map<String, dynamic> item) =>
      int.tryParse(item['id']?.toString() ?? '') ?? 0;

  /// ตรงกับกฎใน api.php: ถ้า claimed / returned แล้ว จะแก้ไข/ลบไม่ได้
  bool _canModify(Map<String, dynamic> item) {
    final s = item['status']?.toString() ?? '';
    return s != 'claimed' && s != 'returned';
  }

  int _myItemsTab = 0; // 0=ทั้งหมด, 1=กำลังดำเนินการ, 2=คืนสำเร็จแล้ว (ประวัติ)

  Widget _buildMyItemsSection() {
    final activeList = myItems.where((e) => e['status'] != 'returned').toList();
    final returnedList = myItems.where((e) => e['status'] == 'returned').toList();

    List<Map<String, dynamic>> displayList;
    if (_myItemsTab == 1) {
      displayList = activeList;
    } else if (_myItemsTab == 2) {
      displayList = returnedList;
    } else {
      displayList = myItems;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'รายการของฉัน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kText,
                  ),
                ),
              ),
              if (myItems.isNotEmpty)
                Text(
                  '${myItems.length} รายการ',
                  style: const TextStyle(fontSize: 12, color: kGrey),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter Tabs สำหรับประวัติ/รายการของฉัน
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _historyTabChip(0, 'ทั้งหมด (${myItems.length})'),
                const SizedBox(width: 8),
                _historyTabChip(1, 'กำลังดำเนินการ (${activeList.length})'),
                const SizedBox(width: 8),
                _historyTabChip(2, 'คืนสำเร็จแล้ว/ประวัติ (${returnedList.length})', isSuccess: true),
              ],
            ),
          ),
          const Divider(height: 20),
          if (loadingStats && myItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (displayList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      _myItemsTab == 2 ? Icons.history : Icons.inbox_outlined,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _myItemsTab == 2
                          ? 'ยังไม่มีประวัติรายการที่คืนสำเร็จ'
                          : (_myItemsTab == 1
                              ? 'ไม่มีรายการที่กำลังดำเนินการ'
                              : 'ยังไม่มีรายการที่แจ้ง'),
                      style: const TextStyle(color: kGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < displayList.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _buildMyItemTile(displayList[i]),
            ],
          if (myItems.any((e) => !_canModify(e))) ...[
            const SizedBox(height: 10),
            const Text(
              'รายการที่มีผู้ขอรับ/คืนแล้ว จะถูกบันทึกเป็นประวัติและแก้ไขไม่ได้',
              style: TextStyle(fontSize: 11, color: kGrey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyTabChip(int index, String label, {bool isSuccess = false}) {
    final selected = _myItemsTab == index;
    final color = isSuccess ? const Color(0xFF16A34A) : kBlue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? color : kText,
      ),
      onSelected: (val) {
        if (val) setState(() => _myItemsTab = index);
      },
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
    width: 56,
    height: 56,
    color: const Color(0xFFE2E8F0),
    child: const Icon(Icons.image_outlined, color: kGrey),
  );

  Widget _buildMyItemTile(Map<String, dynamic> item) {
    final name = item['item_name']?.toString() ?? 'ไม่มีชื่อ';
    final status = item['status']?.toString() ?? '';
    final isFound = item['type']?.toString() == 'found';
    final imgs = _splitImages(item['image_url']?.toString());
    final img = imgs.isNotEmpty ? imgs.first : '';
    final canModify = _canModify(item);
    final id = _itemId(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: img.isNotEmpty
                ? Image.network(
                    img,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                  )
                : _thumbPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _miniChip(
                      isFound ? 'พบของ' : 'ของหาย',
                      isFound ? const Color(0xFF0D9488) : kBlue,
                    ),
                    _miniChip(
                      _statusLabel[status] ?? status,
                      _statusColor(status),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canModify) ...[
            IconButton(
              tooltip: 'แก้ไข',
              visualDensity: VisualDensity.compact,
              onPressed: deletingId == id ? null : () => _editItem(item),
              icon: const Icon(Icons.edit_outlined, color: kBlue, size: 22),
            ),
            deletingId == id
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'ลบ',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 22,
                    ),
                  ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.lock_outline, color: kGrey, size: 18),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = _itemId(item);
    if (id <= 0 || _userId <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบรายการ'),
        content: Text(
          'ต้องการลบ "${item['item_name'] ?? 'รายการนี้'}" ใช่หรือไม่?\nการลบไม่สามารถย้อนกลับได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => deletingId = id);
    final res = await ApiService.deleteItem(itemId: id, userId: _userId);
    if (!mounted) return;
    setState(() => deletingId = null);

    if (res['success'] == true) {
      _toast(
        res['message']?.toString() ?? 'ลบรายการสำเร็จ',
        color: Colors.green,
      );
      _loadStats();
    } else {
      _toast(
        res['message']?.toString() ?? 'ลบรายการไม่สำเร็จ',
        color: Colors.red,
      );
    }
  }

  /// เปิดหน้าแจ้งเดิม (ReportItemPage) ในโหมดแก้ไข
  Future<void> _editItem(Map<String, dynamic> item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportItemPage(userData: user, editItem: item),
      ),
    );

    if (saved == true && mounted) _loadStats();
  }

  // ---------- ปุ่มไปหน้าติดตามสถานะ ----------
  Widget _buildStatusEntry() {
    return InkWell(
      onTap: () {
        if (_userId <= 0) {
          _toast('ไม่พบรหัสผู้ใช้ กรุณาเข้าสู่ระบบใหม่', color: Colors.red);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StatusPage(userId: _userId)),
        ).then((_) => _loadStats());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.track_changes_outlined, color: kBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ติดตามสถานะของฉัน',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: kText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ดูขั้นตอน / สถานะของรายการที่แจ้งและคำขอรับของ',
                    style: TextStyle(fontSize: 11, color: kGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kGrey),
          ],
        ),
      ),
    );
  }

  // ---------- ปุ่มเข้าสู่หน้าแอดมิน ----------
  Widget _buildAdminEntry() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminHomePage(userData: user)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Color(0xFF334155),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Icon(Icons.admin_panel_settings, color: Colors.amber),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เข้าสู่หน้าผู้ดูแลระบบ (Admin Panel)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ตรวจสอบรายการ, คำขอรับของ และห้องแชท',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // ---------- การ์ดข้อมูลบัญชี ----------
  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ข้อมูลบัญชี',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kText,
                  ),
                ),
              ),
              if (!editing)
                TextButton.icon(
                  onPressed: _startEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('แก้ไข'),
                ),
            ],
          ),
          const Divider(height: 20),
          if (editing) _buildEditForm() else _buildInfoView(),
        ],
      ),
    );
  }

  Widget _buildInfoView() {
    return Column(
      children: [
        _infoRow(Icons.badge_outlined, 'ชื่อ-นามสกุล', _name),
        const SizedBox(height: 14),
        _infoRow(
          Icons.email_outlined,
          'อีเมล',
          _email.isEmpty ? 'ไม่ระบุอีเมล' : _email,
        ),
        const SizedBox(height: 14),
        _infoRow(
          Icons.phone_outlined,
          'เบอร์โทรศัพท์',
          _phone.isEmpty ? 'ไม่ระบุเบอร์โทรศัพท์' : _phone,
        ),
        const SizedBox(height: 14),
        _infoRow(Icons.verified_user_outlined, 'สถานะผู้ใช้', _role),
      ],
    );
  }

  Widget _buildEditForm() {
    InputDecoration deco(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBlue, width: 2),
      ),
    );

    return Column(
      children: [
        TextField(
          controller: nameController,
          decoration: deco('ชื่อ-นามสกุล', Icons.badge_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: deco('อีเมล', Icons.email_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: deco('เบอร์โทรศัพท์', Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        _infoRow(
          Icons.verified_user_outlined,
          'สถานะผู้ใช้ (แก้ไขไม่ได้)',
          _role,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving
                    ? null
                    : () => setState(() => editing = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('ยกเลิก'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'บันทึก',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: kGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// image_url ในฐานข้อมูลเก็บหลายรูปคั่นด้วย "," (ตามหน้าแจ้งของหาย/พบของ)
List<String> _splitImages(String? raw) => (raw ?? '')
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .map((e) => ApiService.imageUrl(e))
    .toList();

