import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_chat_list_page.dart';
import '../shared/chat_room_page.dart';
import '../auth/login_page.dart';
import '../user/report_item_page.dart';

/// หน้าแรกฝั่ง Admin: ตรวจสอบรายการที่ผู้ใช้แจ้ง และคำขอรับของ
/// เข้าถึงได้เฉพาะบัญชีที่ users.role = 'admin' (ผ่านมาจาก LoginPage)
class AdminHomePage extends StatefulWidget {
  final dynamic userData;

  const AdminHomePage({super.key, required this.userData});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const Color kBlue = Color(
    0xFF1E293B,
  ); // โทนกลางคืน ให้ดูต่างจากฝั่ง user
  static const Color kAccent = Color(0xFF2563EB);
  static const Color kBg = Color(0xFFF1F5F9);

  int navIndex = 0;

  int get adminId =>
      int.tryParse(widget.userData?['id']?.toString() ?? '') ?? 0;
  String get adminName =>
      widget.userData?['full_name']?.toString() ??
      widget.userData?['username']?.toString() ??
      'Admin';

  bool loading = true;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> claims = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    final res = await Future.wait([
      ApiService.getAdminItems(adminId),
      ApiService.getClaims(adminId),
    ]);

    if (!mounted) return;

    setState(() {
      loading = false;
      if (res[0]['success'] == true && res[0]['data'] is List) {
        items = (res[0]['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (res[1]['success'] == true && res[1]['data'] is List) {
        claims = (res[1]['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

  int _claimCount(String status) =>
      claims.where((e) => e['status'] == status).length;

  void _toast(String msg, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบผู้ดูแลใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  /// เปิดหน้าแจ้งของหาย / พบของสำหรับแอดมิน
  void _showAdminReportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'เลือกประเภทการแจ้ง',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_off, color: Color(0xFFEA580C)),
              ),
              title: const Text('แจ้งของหาย', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('ลงทะเบียนรายการสิ่งของที่สูญหาย'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _openAdminReport(asFound: false);
              },
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on, color: Color(0xFF16A34A)),
              ),
              title: const Text('แจ้งพบของ', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('ลงทะเบียนรายการสิ่งของที่พบ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _openAdminReport(asFound: true);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdminReport({required bool asFound}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportItemPage(
          userData: widget.userData,
          startAsFound: asFound,
        ),
      ),
    );
    if (!mounted) return;
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, size: 22),
            const SizedBox(width: 8),
            Text(
              const [
                'แดชบอร์ด',
                'รายการทั้งหมด',
                'คำขอรับของ',
                'แชทกับผู้ใช้',
              ][navIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: IndexedStack(
                index: navIndex,
                children: [
                  _dashboardTab(),
                  _itemsTab(),
                  _claimsTab(),
                  AdminChatListPage(adminId: adminId),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdminReportSheet,
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('แจ้งรายการ'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) => setState(() => navIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: kAccent.withOpacity(0.12),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: kAccent),
            label: 'แดชบอร์ด',
          ),
          NavigationDestination(
            icon: badge(
              const Icon(Icons.fact_check_outlined),
              items.length,
            ),
            selectedIcon: Icon(Icons.fact_check, color: kAccent),
            label: 'รายการ',
          ),
          NavigationDestination(
            icon: badge(
              const Icon(Icons.assignment_turned_in_outlined),
              _claimCount('pending'),
            ),
            selectedIcon: Icon(Icons.assignment_turned_in, color: kAccent),
            label: 'คำขอ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: kAccent),
            label: 'แชท',
          ),
        ],
      ),
    );
  }

  Widget badge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // DASHBOARD
  // =====================================================

  Widget _dashboardTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สวัสดี, ผู้ดูแลระบบ',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      adminName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statCard(
              'รายการทั้งหมด',
              items.length,
              Icons.inventory_2_outlined,
              const Color(0xFF2563EB),
            ),
            _statCard(
              'คำขอรอตรวจสอบ',
              _claimCount('pending'),
              Icons.assignment_late,
              const Color(0xFFDC2626),
            ),
            _statCard(
              'ของหาย',
              items.where((e) => e['type'] == 'lost').length,
              Icons.search_off,
              const Color(0xFFEA580C),
            ),
            _statCard(
              'พบของ',
              items.where((e) => e['type'] == 'found').length,
              Icons.location_on,
              const Color(0xFF16A34A),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'การดำเนินการด่วน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _taskTile(
          icon: Icons.add_circle_outline,
          color: kAccent,
          title: 'แจ้งของหาย / พบของ',
          subtitle: 'เพิ่มรายการใหม่เข้าสู่ระบบ',
          onTap: _showAdminReportSheet,
        ),
        const SizedBox(height: 10),
        _taskTile(
          icon: Icons.assignment_turned_in_outlined,
          color: const Color(0xFFDC2626),
          title: 'คำขอรับของรอตรวจสอบ',
          subtitle: '${_claimCount('pending')} คำขอ รอการยืนยัน',
          onTap: () => setState(() => navIndex = 2),
        ),
        const SizedBox(height: 10),
        _taskTile(
          icon: Icons.fact_check_outlined,
          color: const Color(0xFFEA580C),
          title: 'ดูรายการทั้งหมด',
          subtitle: '${items.length} รายการในระบบ',
          onTap: () => setState(() => navIndex = 1),
        ),
      ],
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _taskTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ITEMS TAB (ตรวจสอบรายการ)
  // =====================================================

  Widget _itemsTab() {
    if (items.isEmpty) return _empty('ยังไม่มีรายการแจ้งเข้ามา');

    final lostItems = items.where((e) => e['type'] == 'lost').toList();
    final foundItems = items.where((e) => e['type'] == 'found').toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (lostItems.isNotEmpty) ...[
          _sectionTitle('ของหาย', lostItems.length, const Color(0xFFEA580C)),
          const SizedBox(height: 10),
          ...lostItems.map(_itemCard),
          const SizedBox(height: 18),
        ],
        if (foundItems.isNotEmpty) ...[
          _sectionTitle('พบของ', foundItems.length, const Color(0xFF16A34A)),
          const SizedBox(height: 10),
          ...foundItems.map(_itemCard),
        ],
      ],
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final isFound = item['type'] == 'found';
    final img = ApiService.imageUrl(
        item['image_url']?.toString().split(',').first.trim() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: img.isEmpty
                      ? Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        )
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _tag(
                          isFound ? 'พบของ' : 'ของหาย',
                          isFound
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 6),
                        _statusTag(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['item_name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'แจ้งโดย ${item['full_name'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'หมวด ${item['category_name'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _chatWithUser(
                  userId: int.tryParse(item['user_id']?.toString() ?? '') ?? 0,
                  userName: item['full_name']?.toString() ?? 'ผู้ใช้',
                  itemId: int.tryParse(item['id']?.toString() ?? ''),
                  itemName: item['item_name']?.toString(),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 15, color: kAccent),
                label: const Text('แชทกับผู้แจ้ง', style: TextStyle(color: kAccent, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chatWithUser({
    required int userId,
    required String userName,
    int? itemId,
    String? itemName,
  }) async {
    if (userId <= 0) {
      _toast('ไม่พบข้อมูลรหัสผู้ใช้สำหรับเปิดแชท', color: Colors.red);
      return;
    }

    _toast('กำลังเปิดห้องแชท...');

    final convRes = await ApiService.createConversation(
      userId: userId,
      adminId: adminId,
      itemId: itemId,
    );

    if (!mounted) return;

    final convId = int.tryParse(
        (convRes['data']?['id'] ?? convRes['data']?['conversation_id'])
                ?.toString() ??
            '');

    if (convRes['success'] != true || convId == null) {
      _toast(convRes['message']?.toString() ?? 'เปิดห้องแชทไม่สำเร็จ',
          color: Colors.red);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          conversationId: convId,
          currentUserId: adminId,
          title: userName,
          subtitle: itemName != null ? 'เรื่อง: $itemName' : 'ผู้ใช้งาน',
        ),
      ),
    );
  }




  // =====================================================
  // CLAIMS TAB (คำขอรับของ)
  // =====================================================

  Widget _claimsTab() {
    final pending = claims.where((e) => e['status'] == 'pending').toList();
    final others = claims.where((e) => e['status'] != 'pending').toList();

    if (claims.isEmpty) return _empty('ยังไม่มีคำขอรับของ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionTitle('รอตรวจสอบ', pending.length, const Color(0xFFDC2626)),
          const SizedBox(height: 10),
          ...pending.map(_claimCard),
          const SizedBox(height: 18),
        ],
        _sectionTitle('ประวัติทั้งหมด', others.length, Colors.grey),
        const SizedBox(height: 10),
        ...others.map(_claimCard),
      ],
    );
  }

  Widget _claimCard(Map<String, dynamic> claim) {
    final status = claim['status']?.toString() ?? 'pending';
    final img = claim['image_url']?.toString().split(',').first.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: img.isEmpty
                      ? Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        )
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusTag(status),
                    const SizedBox(height: 6),
                    Text(
                      'ของ: ${claim['item_name'] ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ผู้ยื่นขอ: ${claim['full_name'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey,
                      ),
                    ),
                    if ((claim['phone']?.toString() ?? '').isNotEmpty)
                      Text(
                        'โทร: ${claim['phone']}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              claim['description']?.toString() ?? '-',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _chatWithUser(
                  userId: int.tryParse(claim['user_id']?.toString() ?? '') ?? 0,
                  userName: claim['full_name']?.toString() ?? 'ผู้ยื่นคำขอ',
                  itemId: int.tryParse(claim['item_id']?.toString() ?? ''),
                  itemName: claim['item_name']?.toString(),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 15, color: kAccent),
                label: const Text('แชทกับผู้ยื่นคำขอ', style: TextStyle(color: kAccent, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decideClaim(claim, approve: false),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text(
                      'ปฏิเสธ',
                      style: TextStyle(color: Colors.red, fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _decideClaim(claim, approve: true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'อนุมัติ + คืนของ',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decideClaim(
    Map<String, dynamic> claim, {
    required bool approve,
  }) async {
    final claimId = int.tryParse(claim['id'].toString()) ?? 0;
    final noteController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approve ? 'ยืนยันคืนของให้ผู้ยื่นขอ' : 'ปฏิเสธคำขอนี้'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: approve ? 'หมายเหตุ (ถ้ามี)' : 'เหตุผลที่ปฏิเสธ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? const Color(0xFF16A34A) : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'ยืนยัน' : 'ปฏิเสธ'),
          ),
        ],
      ),
    );

    final note = noteController.text.trim();
    noteController.dispose();

    if (ok != true) return;

    final res = approve
        ? await ApiService.approveClaim(
            adminId: adminId,
            claimId: claimId,
            note: note,
          )
        : await ApiService.rejectClaim(
            adminId: adminId,
            claimId: claimId,
            note: note,
          );

    if (!mounted) return;

    if (res['success'] == true) {
      _toast(
        approve ? 'ยืนยันการคืนของแล้ว' : 'ปฏิเสธคำขอแล้ว',
        color: Colors.green,
      );
      _loadAll();
    } else {
      _toast(
        res['message']?.toString() ?? 'ดำเนินการไม่สำเร็จ',
        color: Colors.red,
      );
    }
  }


  // ---------- ชิ้นส่วนย่อย ----------

  Widget _sectionTitle(String text, int count, Color color) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _statusTag(String status) {
    final map = {
      'pending': ['รอตรวจสอบ', const Color(0xFFEA580C)],
      'approved': ['อนุมัติแล้ว', const Color(0xFF2563EB)],
      'rejected': ['ปฏิเสธแล้ว', const Color(0xFFDC2626)],
      'claimed': ['มีผู้ยื่นขอรับ', const Color(0xFF7C3AED)],
      'returned': ['คืนสำเร็จ', const Color(0xFF16A34A)],
    };
    final v = map[status] ?? ['ไม่ทราบสถานะ', Colors.grey];
    return _tag(v[0] as String, v[1] as Color);
  }

  Widget _empty(String text) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_outlined, size: 50, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Center(
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
