import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../shared/chat_room_page.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final dynamic currentUser;
  const ItemDetailPage({super.key, required this.item, required this.currentUser});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kTeal = Color(0xFF0F766E);
  static const Color kText = Color(0xFF1E293B);
  int _currentImage = 0;
  bool _claiming = false;
  bool _reporting = false;

  Map<String, dynamic> get item => widget.item;
  bool get isFound => item['type'] == 'found';
  Color get typeColor => isFound ? kTeal : Colors.orange.shade700;

  List<String> get imageUrls {
    final raw = item['image_url']?.toString() ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((e) => ApiService.imageUrl(e.trim())).where((e) => e.isNotEmpty).toList();
  }

  String _formatDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year + 543}';
  }

  Future<void> _claimItem() async {
    final userId = int.tryParse(widget.currentUser['id']?.toString() ?? '') ?? 0;
    if (userId == 0) return;

    final controller = TextEditingController();
    XFile? selectedImage;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('ยื่นสิทธิ์ความเป็นเจ้าของ'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                                  title: const Text('ถ่ายรูป'),
                                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
                                  title: const Text('เลือกจากแกลเลอรี'),
                                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
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
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 32, color: Color(0xFF94A3B8)),
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
                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                          label: const Text('ลบรูป',
                              style: TextStyle(fontSize: 12, color: Colors.red)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'อธิบายลักษณะเฉพาะของสิ่งของ\nเพื่อยืนยันว่าเป็นของคุณ',
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

    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null) return;

    final description = result['description'] as String? ?? '';
    final image = result['image'] as XFile?;

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาถ่ายรูปหรือเลือกรูปภาพหลักฐาน'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณากรอกรายละเอียดเพื่อยืนยันความเป็นเจ้าของ'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _claiming = true);

    // อัพโหลดรูปภาพก่อน
    final uploadRes = await ApiService.uploadImage(image);
    if (!mounted) return;

    String evidenceImageUrl = '';
    if (uploadRes['success'] == true && uploadRes['data'] != null) {
      evidenceImageUrl = uploadRes['data']['url']?.toString() ?? '';
    } else {
      setState(() => _claiming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploadRes['message']?.toString() ?? 'อัพโหลดรูปภาพไม่สำเร็จ'),
        backgroundColor: Colors.red.shade600,
      ));
      return;
    }

    final res = await ApiService.claim(
      itemId: int.tryParse(item['id'].toString()) ?? 0,
      userId: userId,
      description: description,
      evidenceImage: evidenceImageUrl,
    );
    if (!mounted) return;
    setState(() => _claiming = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message']?.toString() ?? ''),
      backgroundColor: res['success'] == true ? kTeal : Colors.red.shade600,
    ));
  }

  Future<void> _reportFound() async {
    final myId = int.tryParse(widget.currentUser['id']?.toString() ?? '') ?? 0;
    if (myId == 0) return;

    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.volunteer_activism, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('แจ้งว่าพบของ', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'กรอกรายละเอียดเพื่อแจ้งเจ้าของว่าคุณพบของชิ้นนี้แล้ว',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: locationCtrl,
              decoration: InputDecoration(
                labelText: 'สถานที่ที่พบ *',
                hintText: 'เช่น ห้องสมุด ชั้น 2',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                hintText: 'เช่น ลักษณะที่พบ วิธีติดต่อ',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (locationCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _reporting = true);
    final res = await ApiService.reportFound(
      lostItemId: int.tryParse(item['id'].toString()) ?? 0,
      finderId: myId,
      location: locationCtrl.text.trim(),
      description: descCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _reporting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message']?.toString() ?? ''),
      backgroundColor: res['success'] == true ? kTeal : Colors.red.shade600,
    ));

    if (res['success'] == true) {
      // offer to open chat after reporting
      final openChat = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('แจ้งสำเร็จ 🎉'),
          content: const Text('ต้องการแชทกับแอดมินเพื่อนัดรับของต่อหรือไม่?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ไม่ใช่')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('แชทเลย', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (openChat == true && mounted) _openChat();
    }
  }

  Future<void> _openChat() async {
    final myId = int.tryParse(widget.currentUser['id']?.toString() ?? '') ?? 0;
    if (myId == 0) return;
    final adminRes = await ApiService.getDefaultAdmin();
    if (!mounted) return;
    final adminId = int.tryParse(adminRes['data']?['id']?.toString() ?? '') ?? 0;
    if (adminId == 0) return;
    final adminName = adminRes['data']?['full_name']?.toString() ?? 'ผู้ดูแลระบบ';
    final convRes = await ApiService.createConversation(
      userId: myId,
      adminId: adminId,
      itemId: int.tryParse(item['id'].toString()) ?? 0,
    );
    if (!mounted) return;
    final convId = int.tryParse(
      (convRes['data']?['id'] ?? convRes['data']?['conversation_id'])?.toString() ?? '',
    ) ?? 0;
    if (convId == 0) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatRoomPage(
        conversationId: convId,
        currentUserId: myId,
        title: adminName,
        subtitle: 'สอบถามเกี่ยวกับ: ${item['item_name'] ?? ''}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final images = imageUrls;
    final name = item['item_name']?.toString() ?? '-';
    final description = item['description']?.toString() ?? '';
    final location = item['location']?.toString() ?? '-';
    final date = _formatDate(item['lost_found_date'] ?? item['created_at']);
    final reporter = item['full_name']?.toString() ?? '-';
    final color = item['color']?.toString() ?? '';
    final category = item['category_name']?.toString() ?? '';
    final myId = widget.currentUser['id']?.toString() ?? '';
    final ownerId = item['user_id']?.toString() ?? '';
    final isOwner = myId.isNotEmpty && myId == ownerId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: images.isEmpty ? 200 : 300,
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: kText,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: images.isEmpty
                ? Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey),
                    ),
                  )
                : Stack(children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentImage = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.broken_image_outlined, size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImage == i ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _currentImage == i ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                        ),
                      ),
                    Positioned(
                      top: 60,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isFound ? Icons.check_circle : Icons.search, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              isFound ? 'พบของ' : 'ของหาย',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kText),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (category.isNotEmpty) _chip(Icons.category_outlined, category, const Color(0xFFEFF6FF), kBlue),
                    if (color.isNotEmpty) _chip(Icons.palette_outlined, 'สี: $color', const Color(0xFFFFF7ED), Colors.orange.shade700),
                  ],
                ),
                const SizedBox(height: 16),
                _infoCard([
                  _infoRow(Icons.location_on_outlined, 'สถานที่', location, kBlue),
                  const Divider(height: 20),
                  _infoRow(Icons.calendar_today_outlined, 'วันที่', date, Colors.purple.shade400),
                ]),
                const SizedBox(height: 12),
                if (description.isNotEmpty) ...[
                  _sectionLabel('รายละเอียด'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _sectionLabel('ผู้แจ้ง'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: typeColor.withOpacity(0.15),
                        child: Text(
                          reporter.isNotEmpty ? reporter[0].toUpperCase() : 'U',
                          style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reporter, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kText)),
                            Text(isFound ? 'ผู้แจ้งพบของ' : 'เจ้าของของหาย', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ]),
      bottomNavigationBar: isOwner ? null : Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('แชท', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBlue,
                  side: const BorderSide(color: kBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: isFound
                  ? ElevatedButton.icon(
                      onPressed: _claiming ? null : _claimItem,
                      icon: _claiming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.shield_outlined, size: 18),
                      label: Text(
                        _claiming ? 'กำลังส่ง...' : 'ยื่นสิทธิ์ความเป็นเจ้าของ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _reporting ? null : _reportFound,
                      icon: _reporting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.volunteer_activism, size: 18),
                      label: Text(
                        _reporting ? 'กำลังส่ง...' : 'ฉันเจอของชิ้นนี้',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String label, String value, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: kText, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.3),
      );
}