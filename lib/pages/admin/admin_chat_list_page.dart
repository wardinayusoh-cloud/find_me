import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../shared/chat_room_page.dart';

/// รายการห้องแชททั้งหมดที่มีคนทัก Admin คนนี้เข้ามา
class AdminChatListPage extends StatefulWidget {
  final int adminId;

  const AdminChatListPage({super.key, required this.adminId});

  @override
  State<AdminChatListPage> createState() => _AdminChatListPageState();
}

class _AdminChatListPageState extends State<AdminChatListPage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);

  bool loading = true;
  List<Map<String, dynamic>> conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final res = await ApiService.getAdminConversations(widget.adminId);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res['success'] == true && res['data'] is List) {
        conversations = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
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
    if (loading) return const Center(child: CircularProgressIndicator());

    if (conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Center(
              child: Text('ยังไม่มีผู้ใช้ทักเข้ามา',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (_, i) => _convTile(conversations[i]),
      ),
    );
  }

  Widget _convTile(Map<String, dynamic> c) {
    final userName = c['user_full_name']?.toString() ?? '-';
    final username = c['user_username']?.toString() ?? '';
    final itemName = c['item_name']?.toString();
    final lastMsg = c['last_message']?.toString();
    final avatar = ApiService.imageUrl(c['user_avatar_url']?.toString() ?? '');

    return InkWell(
      onTap: () async {
        final convId = int.tryParse(c['id'].toString()) ?? 0;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              conversationId: convId,
              currentUserId: widget.adminId,
              title: userName,
              subtitle: itemName != null ? 'เรื่อง: $itemName' : '@$username',
            ),
          ),
        );
        _load();
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
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: kBlue, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kText)),
                  const SizedBox(height: 2),
                  Text(
                    lastMsg?.isNotEmpty == true
                        ? lastMsg!
                        : (itemName != null ? 'เรื่อง: $itemName' : 'แชททั่วไป'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(_timeAgo(c['updated_at']),
                style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
