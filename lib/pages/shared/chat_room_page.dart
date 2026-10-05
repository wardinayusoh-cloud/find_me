import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

/// ห้องแชท 1 ห้อง — ใช้ได้ 2 โหมด:
/// - โหมดปกติ (isPeerChat = false): คุยกับ Admin ผ่านตาราง conversations/messages
/// - โหมดนัดรับของ (isPeerChat = true): คุยกันเองระหว่าง "ผู้แจ้ง" กับ "ผู้ยื่นขอรับ"
///   ผ่านตาราง item_chats/item_chat_messages (เปิดได้ก็ต่อเมื่อแอดมินอนุมัติ claim แล้ว)
/// [currentUserId] คือคนที่กำลังเปิดหน้านี้อยู่ (ใช้ตัดสินว่าฟองข้อความไหนคือ "ฉัน")
class ChatRoomPage extends StatefulWidget {
  final int conversationId;
  final int currentUserId;
  final String title;
  final String? subtitle;
  final bool isPeerChat;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.title,
    this.subtitle,
    this.isPeerChat = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kBg = Color(0xFFF1F5F9);

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool sending = false;
  bool sendingImage = false;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    _load(scrollToBottom: true);
    // ดึงข้อความใหม่ทุก 4 วินาที (ไม่มี websocket ในระบบนี้)
    pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    textController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool scrollToBottom = false}) async {
    final res = widget.isPeerChat
        ? await ApiService.getItemChatMessages(widget.conversationId)
        : await ApiService.getMessages(widget.conversationId);
    if (!mounted) return;

    if (res['success'] == true && res['data'] is List) {
      final list = (res['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final changed = list.length != messages.length;

      setState(() {
        messages = list;
        loading = false;
      });

      if (changed || scrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
      }
    } else {
      setState(() => loading = false);
    }
  }

  void _scrollDown() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = textController.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);
    textController.clear();

    final res = widget.isPeerChat
        ? await ApiService.sendItemChatMessage(
            itemChatId: widget.conversationId,
            senderId: widget.currentUserId,
            message: text,
          )
        : await ApiService.sendMessage(
            conversationId: widget.conversationId,
            senderId: widget.currentUserId,
            message: text,
          );

    if (!mounted) return;
    setState(() => sending = false);

    if (res['success'] == true) {
      await _load(scrollToBottom: true);
    } else {
      textController.text = text; // คืนข้อความกลับถ้าส่งไม่สำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ส่งข้อความไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendImage() async {
    if (sendingImage) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1000,
    );
    if (picked == null) return;

    setState(() => sendingImage = true);

    final up = await ApiService.uploadImage(picked);

    if (!mounted) return;

    final url = (up['data'] is Map) ? up['data']['url']?.toString() : null;

    if (up['success'] != true || url == null || url.isEmpty) {
      setState(() => sendingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(up['message']?.toString() ?? 'อัปโหลดรูปไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final res = widget.isPeerChat
        ? await ApiService.sendItemChatMessage(
            itemChatId: widget.conversationId,
            senderId: widget.currentUserId,
            imageUrl: url,
          )
        : await ApiService.sendMessage(
            conversationId: widget.conversationId,
            senderId: widget.currentUserId,
            imageUrl: url,
          );

    if (!mounted) return;
    setState(() => sendingImage = false);

    if (res['success'] == true) {
      await _load(scrollToBottom: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ส่งรูปไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _time(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(
                    child: Text(
                      'เริ่มบทสนทนาได้เลย',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _bubble(messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final senderId = int.tryParse(m['sender_id'].toString()) ?? -1;
    final isMe = senderId == widget.currentUserId;
    final isAdmin = m['role'] == 'admin';
    final text = m['message']?.toString() ?? '';
    final img = ApiService.imageUrl(m['image_url']?.toString() ?? '');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  isAdmin
                      ? 'แอดมิน · ${m['full_name'] ?? ''}'
                      : (m['full_name'] ?? ''),
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? kBlue
                    : (isAdmin ? const Color(0xFFDCFCE7) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (img.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        img,
                        width: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 180,
                          height: 120,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isMe ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _time(m['created_at']),
                style: const TextStyle(fontSize: 9.5, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: sendingImage ? null : _sendImage,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: sendingImage
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            ),
            Expanded(
              child: TextField(
                controller: textController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  filled: true,
                  fillColor: kBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: sending ? null : _send,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: kBlue,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
