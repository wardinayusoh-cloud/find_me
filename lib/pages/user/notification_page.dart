import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../shared/chat_room_page.dart';

class NotificationPage extends StatefulWidget {
  final int userId;

  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);

  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => loading = true);
    final res = await ApiService.getNotifications(widget.userId);
    if (!mounted) return;

    if (res['success'] == true && res['data'] is List) {
      notifications = (res['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    setState(() => loading = false);

    // ทำเครื่องหมายว่าอ่านแล้วอัตโนมัติ
    if (notifications.any((n) => n['is_read'] == 0 || n['is_read'] == false)) {
      ApiService.markNotificationsRead(widget.userId);
    }
  }

  String _formatTime(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year + 543} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'การแจ้งเตือน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kText,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _emptyView()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _itemCard(notifications[i]),
                  ),
                ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final isRead = item['is_read'] == 1 || item['is_read'] == true;
    final title = item['title']?.toString() ?? 'การแจ้งเตือน';
    final msg = item['message']?.toString() ?? '';
    final time = _formatTime(item['created_at']);

    final isClaim = title.contains('ยื่นสิทธิ์') || title.contains('เจ้าของ');
    final isChat = title.contains('ข้อความ') || title.contains('ติดต่อ') || title.contains('แชท');
    final canOpenChat = isClaim || isChat;

    Color iconBg = isRead ? const Color(0xFFE2E8F0) : kBlue;
    IconData notifIcon = Icons.notifications_outlined;

    if (isClaim) {
      iconBg = isRead ? const Color(0xFFE2E8F0) : const Color(0xFFEA580C);
      notifIcon = Icons.verified_user_outlined;
    } else if (isChat) {
      iconBg = isRead ? const Color(0xFFE2E8F0) : const Color(0xFF0F766E);
      notifIcon = Icons.chat_bubble_outline;
    }

    return GestureDetector(
      onTap: canOpenChat ? () => _openChatFromNotification(item) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : (isClaim ? const Color(0xFFFFF7ED) : (isChat ? const Color(0xFFF0FDFA) : const Color(0xFFEFF6FF))),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : (isClaim ? const Color(0xFFFED7AA) : (isChat ? const Color(0xFF99F6E4) : const Color(0xFFBFDBFE))),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconBg,
              child: Icon(
                notifIcon,
                size: 20,
                color: isRead ? Colors.grey : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14,
                      color: kText,
                    ),
                  ),
                  if (msg.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      msg,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                  if (canOpenChat) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 13,
                          color: isClaim ? Colors.orange.shade700 : const Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isChat ? 'กดเพื่อเข้าสู่ห้องแชท' : 'กดเพื่อเปิดห้องแชทกับผู้ติดต่อ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isClaim ? Colors.orange.shade700 : const Color(0xFF0F766E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (canOpenChat)
              Icon(
                Icons.chevron_right,
                color: isClaim ? Colors.orange.shade400 : const Color(0xFF0F766E),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'ไม่มีการแจ้งเตือนในขณะนี้',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// เปิดห้องแชทกับผู้ยื่นสิทธิ์ เมื่อกด notification ประเภท claim
  Future<void> _openChatFromNotification(Map<String, dynamic> item) async {
    // ดึง claim_id หรือ item_id จาก notification payload
    final claimId = int.tryParse(item['claim_id']?.toString() ?? '0') ?? 0;
    final itemId  = int.tryParse(item['item_id']?.toString()  ?? '0') ?? 0;

    if (claimId <= 0 && itemId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูล claim ในการแจ้งเตือนนี้')),
      );
      return;
    }

    final res = await ApiService.openItemChat(
      claimId: claimId > 0 ? claimId : null,
      itemId:  itemId  > 0 ? itemId  : null,
      userId: widget.userId,
    );

    if (!mounted) return;

    if (res['success'] != true || res['data'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'เปิดห้องแชทไม่สำเร็จ')),
      );
      return;
    }

    final data       = res['data'];
    final itemChatId = int.tryParse(data['item_chat_id'].toString()) ?? 0;
    final peerName   = data['peer_name']?.toString() ?? 'ผู้ใช้งาน';
    final itemName   = data['item_name']?.toString() ?? '';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          conversationId: itemChatId,
          currentUserId: widget.userId,
          title: peerName,
          subtitle: 'ยื่นสิทธิ์: $itemName',
          isPeerChat: true,
        ),
      ),
    );
  }
}
