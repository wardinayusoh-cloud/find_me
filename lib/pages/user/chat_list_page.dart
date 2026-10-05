import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../shared/chat_room_page.dart';

/// รายการแชทของผู้ใช้ แบ่งเป็น 2 แท็บ:
/// 1) แอดมิน — คุยกับผู้ดูแลระบบ (สอบถามทั่วไป / เรื่องรายการที่แจ้ง)
/// 2) นัดรับของ — คุยกันเองระหว่างผู้แจ้งกับผู้ยื่นขอรับ หลังแอดมินยืนยันแล้ว
class ChatListPage extends StatefulWidget {
  final int userId;

  const ChatListPage({super.key, required this.userId});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with SingleTickerProviderStateMixin {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);

  late TabController tabController;

  bool loadingAdmin = true;
  bool loadingPeer = true;
  bool starting = false;

  List<Map<String, dynamic>> adminConversations = [];
  List<Map<String, dynamic>> peerChats = [];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging) setState(() {});
    });
    _loadAdmin();
    _loadPeer();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    setState(() => loadingAdmin = true);
    final res = await ApiService.getConversations(widget.userId);
    if (!mounted) return;
    setState(() {
      loadingAdmin = false;
      if (res['success'] == true && res['data'] is List) {
        adminConversations = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

  Future<void> _loadPeer() async {
    setState(() => loadingPeer = true);
    final res = await ApiService.getItemChats(widget.userId);
    if (!mounted) return;
    setState(() {
      loadingPeer = false;
      if (res['success'] == true && res['data'] is List) {
        peerChats = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

  void _toast(String msg, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  /// เริ่มแชททั่วไปกับแอดมิน (ไม่ผูกกับรายการใด) — ใช้แอดมินคนแรกในระบบ
  Future<void> _startNewChat() async {
    if (starting) return;
    setState(() => starting = true);

    final adminRes = await ApiService.getDefaultAdmin();

    if (!mounted) return;

    if (adminRes['success'] != true || adminRes['data'] == null) {
      setState(() => starting = false);
      _toast(
        adminRes['message']?.toString() ?? 'ยังไม่มีผู้ดูแลระบบในขณะนี้',
        color: Colors.red,
      );
      return;
    }

    final adminId = int.tryParse(adminRes['data']['id']?.toString() ?? '') ?? 0;
    final adminName =
        adminRes['data']['full_name']?.toString() ??
        adminRes['data']['username']?.toString() ??
        'แอดมิน';

    final convRes = await ApiService.createConversation(
      userId: widget.userId,
      adminId: adminId,
    );

    if (!mounted) return;
    setState(() => starting = false);

    final convId = int.tryParse(
      (convRes['data']?['id'] ?? convRes['data']?['conversation_id'])
              ?.toString() ??
          '',
    );

    if (convRes['success'] != true || convId == null) {
      _toast(
        convRes['message']?.toString() ?? 'เปิดห้องแชทไม่สำเร็จ',
        color: Colors.red,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          conversationId: convId,
          currentUserId: widget.userId,
          title: adminName,
          subtitle: 'ผู้ดูแลระบบ',
        ),
      ),
    );
    _loadAdmin();
  }

  String _timeAgo(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    return '${d.day}/${d.month}/${d.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kText,
        automaticallyImplyLeading: false,
        title: const Text(
          'แชท',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: tabController,
          labelColor: kBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kBlue,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'แอดมิน'),
            Tab(text: 'นัดรับของ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [_adminTab(), _peerTab()],
      ),
      floatingActionButton: tabController.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'chat_fab',
              onPressed: starting ? null : _startNewChat,
              backgroundColor: kBlue,
              icon: starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: const Text(
                'คุยกับแอดมิน',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  // =====================================================
  // แท็บ 1: แชทแอดมิน
  // =====================================================

  Widget _adminTab() {
    if (loadingAdmin) return const Center(child: CircularProgressIndicator());

    if (adminConversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAdmin,
        child: _emptyList(
          icon: Icons.forum_outlined,
          title: 'ยังไม่มีบทสนทนา',
          subtitle: 'กดปุ่ม "คุยกับแอดมิน" ด้านล่างเพื่อเริ่มแชท',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAdmin,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: adminConversations.length,
        itemBuilder: (_, i) => _adminTile(adminConversations[i]),
      ),
    );
  }

  Widget _adminTile(Map<String, dynamic> c) {
    final itemName = c['item_name']?.toString();
    final adminName = c['admin_name']?.toString() ?? 'แอดมิน';

    return InkWell(
      onTap: () async {
        final convId = int.tryParse(c['id'].toString()) ?? 0;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              conversationId: convId,
              currentUserId: widget.userId,
              title: adminName,
              subtitle: itemName != null ? 'เรื่อง: $itemName' : 'ผู้ดูแลระบบ',
            ),
          ),
        );
        _loadAdmin();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFDBEAFE),
              child: Text(
                adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: kBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adminName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemName != null ? 'เรื่อง: $itemName' : 'แชททั่วไป',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              _timeAgo(c['updated_at']),
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // แท็บ 2: แชทนัดรับของ (ระหว่างผู้แจ้งกับผู้ยื่นขอรับ)
  // =====================================================

  Widget _peerTab() {
    if (loadingPeer) return const Center(child: CircularProgressIndicator());

    if (peerChats.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPeer,
        child: _emptyList(
          icon: Icons.handshake_outlined,
          title: 'ยังไม่มีการนัดรับของ',
          subtitle:
              'ห้องแชทจะเปิดขึ้นอัตโนมัติ หลังแอดมินยืนยันคำขอรับของแล้ว\n'
              'ไปเปิดได้ที่หน้า "ติดตามสถานะของฉัน"',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPeer,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: peerChats.length,
        itemBuilder: (_, i) => _peerTile(peerChats[i]),
      ),
    );
  }

  Widget _peerTile(Map<String, dynamic> c) {
    final peerName = c['peer_name']?.toString() ?? 'ผู้ใช้งาน';
    final peerAvatar = c['peer_avatar']?.toString() ?? '';
    final itemName = c['item_name']?.toString() ?? '-';
    final lastMsg = c['last_message']?.toString();

    return InkWell(
      onTap: () async {
        final itemChatId = int.tryParse(c['id'].toString()) ?? 0;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              conversationId: itemChatId,
              currentUserId: widget.userId,
              title: peerName,
              subtitle: 'นัดรับของ: $itemName',
              isPeerChat: true,
            ),
          ),
        );
        _loadPeer();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFDCFCE7),
              backgroundImage: peerAvatar.isNotEmpty
                  ? NetworkImage(peerAvatar)
                  : null,
              child: peerAvatar.isEmpty
                  ? Text(
                      peerName.isNotEmpty ? peerName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMsg?.isNotEmpty == true
                        ? lastMsg!
                        : 'นัดรับของ: $itemName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              _timeAgo(c['updated_at']),
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyList({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Icon(icon, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(
          child: Text(title, style: const TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
