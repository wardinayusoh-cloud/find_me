import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // =====================================================
  // URL ของ PHP API
  // =====================================================

  static const String baseUrl =
      'https://std.mcs.psu.ac.th/6620310157/html/lost_found_api/api.php';

  // =====================================================
  // IMAGE PROXY – ใช้เพื่อหลีกเลี่ยงปัญหา CORS บน Flutter Web
  // รับ URL เต็มหรือแค่ชื่อไฟล์ แล้วแปลงเป็น proxy URL
  // =====================================================

  static String imageUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    // ดึงเฉพาะชื่อไฟล์ (basename) จาก URL หรือ path
    final fileName = rawUrl.split('/').last.split('\\').last;
    if (fileName.isEmpty) return '';
    return '$baseUrl?action=view_image&file=${Uri.encodeComponent(fileName)}';
  }

  // =====================================================
  // REGISTER
  // =====================================================

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=register'),
        body: {
          'username': username,
          'password': password,
          'full_name': fullName,
          'email': email,
          'phone': phone,
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // LOGIN
  // =====================================================

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=login'),
        body: {'username': username, 'password': password},
      );

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      debugPrint('LOGIN RESPONSE: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // CREATE LOST ITEM
  // =====================================================

  static Future<Map<String, dynamic>> createLostItem({
    required String username,
    required String itemName,
    required String category,
    required String color,
    required String location,
    required String lostDate,
    required String description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=create_lost_item'),
        body: {
          'username': username,
          'item_name': itemName,
          'category': category,
          'color': color,
          'location': location,
          'lost_date': lostDate,
          'description': description,
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // GET CATEGORIES
  // action=categories (GET) -> คืน list ของหมวดหมู่ทั้งหมด
  // =====================================================

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'action': 'categories'});

      final response = await http.get(uri);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // GET ITEMS
  // action=items (GET) -> ค้นหา/ดึงรายการของหาย-ของพบ
  // รองรับ keyword, type (lost/found), status (pending/approved/rejected)
  // =====================================================

  static Future<Map<String, dynamic>> getItems({
    String keyword = '',
    String type = '',
    String status = '',
  }) async {
    try {
      final queryParams = <String, String>{'action': 'items'};

      if (keyword.isNotEmpty) queryParams['keyword'] = keyword;
      if (type.isNotEmpty) queryParams['type'] = type;
      if (status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(uri);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // UPLOAD IMAGE
  // action=upload_image (POST, multipart) -> อัปโหลดรูปภาพ 1 ไฟล์
  // คืนค่า data.url เป็นลิงก์รูปที่อัปโหลดแล้ว
  // ใช้สำหรับหน้า "แจ้งเรื่องของหาย / พบของ" (ReportItemPage)
  // =====================================================

  static Future<Map<String, dynamic>> uploadImage(XFile imageFile) async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'action': 'upload_image'});

      final request = http.MultipartRequest('POST', uri);

      // อ่านเป็น bytes เพื่อให้ใช้ได้ทั้งมือถือและ Flutter Web
      final bytes = await imageFile.readAsBytes();

      // ให้แน่ใจว่าชื่อไฟล์มีนามสกุลที่ api.php รองรับ (jpg/jpeg/png/webp)
      String fileName = imageFile.name;
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        final mime = imageFile.mimeType ?? '';
        final newExt = mime.contains('png')
            ? 'png'
            : mime.contains('webp')
            ? 'webp'
            : 'jpg';
        fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.$newExt';
      }

      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปโหลดรูปภาพได้'};
    }
  }

  // =====================================================
  // CREATE ITEM (lost หรือ found)
  // action=add_item -> ใช้สำหรับหน้า "แจ้งเรื่องของหาย / พบของ" (ReportItemPage)
  // รองรับทั้งแจ้งของหาย (type=lost) และแจ้งพบของ (type=found)
  // =====================================================

  static Future<Map<String, dynamic>> createItem({
    required int userId,
    required int categoryId,
    required String type,
    required String itemName,
    String description = '',
    String color = '',
    String location = '',
    String lostFoundDate = '',
    String imageUrl = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=add_item'),
        body: {
          'user_id': userId.toString(),
          'category_id': categoryId.toString(),
          'type': type,
          'item_name': itemName,
          'description': description,
          'color': color,
          'location': location,
          'lost_found_date': lostFoundDate,
          'image_url': imageUrl,
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // REPORT FOUND – แจ้งว่าพบของที่มีคนตามหา
  // action=report_found -> บันทึก found_report + ส่งแจ้งเตือนเจ้าของ
  // =====================================================

  static Future<Map<String, dynamic>> reportFound({
    required int lostItemId,
    required int finderId,
    String location = '',
    String description = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=report_found'),
        body: {
          'lost_item_id': lostItemId.toString(),
          'finder_id': finderId.toString(),
          'location': location,
          'description': description,
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // GET STATS
  // action=stats (GET) -> ใช้สำหรับการ์ดสรุปสถิติหน้า Home
  // (StatBannerCard) คืนจำนวนรายการที่คืนเจ้าของสำเร็จแล้ว
  // =====================================================

  static Future<Map<String, dynamic>> getStats() async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'action': 'stats'});

      final response = await http.get(uri);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // CLAIM (ยื่นสิทธิ์ความเป็นเจ้าของ)
  // action=claim (POST) -> ส่งคำขอรับของที่พบ
  // =====================================================

  static Future<Map<String, dynamic>> claim({
    required int itemId,
    required int userId,
    required String description,
    String evidenceImage = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=claim'),
        body: {
          'item_id': itemId.toString(),
          'user_id': userId.toString(),
          'description': description,
          'evidence_image': evidenceImage,
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // UPDATE PROFILE
  // action=update_profile (POST) -> แก้ไขข้อมูล / เปลี่ยนรูปโปรไฟล์
  // คืน data = ข้อมูล user ล่าสุด (ไม่มี password)
  // =====================================================

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String fullName,
    String email = '',
    String phone = '',
    String avatarUrl = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update_profile'),
        body: {
          'user_id': userId.toString(),
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'avatar_url': avatarUrl,
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // HELPER ภายใน
  // =====================================================

  static Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: query);
      final response = await http.get(uri);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  static Future<Map<String, dynamic>> _post(
    String action,
    Map<String, String> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=$action'),
        body: body,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อ Server ได้'};
    }
  }

  // =====================================================
  // USER: ติดตามสถานะของตัวเอง
  // =====================================================

  /// รายการที่ user แจ้งไว้ (action=my_items)
  static Future<Map<String, dynamic>> getMyItems(int userId) =>
      _get({'action': 'my_items', 'user_id': userId.toString()});

  /// คำขอรับของที่ user ยื่นไว้ (action=my_claims)
  static Future<Map<String, dynamic>> getMyClaims(int userId) =>
      _get({'action': 'my_claims', 'user_id': userId.toString()});

  /// ผู้แจ้งแก้ไขรายการของตัวเอง (action=update_item)
  static Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required int userId,
    required int categoryId,
    required String itemName,
    String description = '',
    String color = '',
    String location = '',
    String lostFoundDate = '',
    String imageUrl = '',
  }) => _post('update_item', {
    'item_id': itemId.toString(),
    'user_id': userId.toString(),
    'category_id': categoryId.toString(),
    'item_name': itemName,
    'description': description,
    'color': color,
    'location': location,
    'lost_found_date': lostFoundDate,
    'image_url': imageUrl,
  });

  /// ผู้แจ้งลบรายการของตัวเอง (action=delete_item)
  static Future<Map<String, dynamic>> deleteItem({
    required int itemId,
    required int userId,
  }) => _post('delete_item', {
    'item_id': itemId.toString(),
    'user_id': userId.toString(),
  });

  // =====================================================
  // ADMIN
  // ทุกฟังก์ชันต้องส่ง adminId เพื่อให้ api.php ตรวจสิทธิ์
  // =====================================================

  static Future<Map<String, dynamic>> getAdminItems(int adminId) =>
      _get({'action': 'admin_items', 'admin_id': adminId.toString()});

  static Future<Map<String, dynamic>> getClaims(int adminId) =>
      _get({'action': 'claims', 'admin_id': adminId.toString()});

  static Future<Map<String, dynamic>> approveItem({
    required int adminId,
    required int itemId,
  }) => _post('approve_item', {
    'admin_id': adminId.toString(),
    'item_id': itemId.toString(),
  });

  static Future<Map<String, dynamic>> rejectItem({
    required int adminId,
    required int itemId,
  }) => _post('reject_item', {
    'admin_id': adminId.toString(),
    'item_id': itemId.toString(),
  });

  static Future<Map<String, dynamic>> approveClaim({
    required int adminId,
    required int claimId,
    String note = '',
  }) => _post('approve_claim', {
    'admin_id': adminId.toString(),
    'claim_id': claimId.toString(),
    'admin_note': note,
  });

  static Future<Map<String, dynamic>> rejectClaim({
    required int adminId,
    required int claimId,
    String note = '',
  }) => _post('reject_claim', {
    'admin_id': adminId.toString(),
    'claim_id': claimId.toString(),
    'admin_note': note,
  });

  // =====================================================
  // CHAT: User <-> Admin
  // =====================================================

  /// ห้องแชททั้งหมดของ user คนนี้ (action=conversations)
  static Future<Map<String, dynamic>> getConversations(int userId) =>
      _get({'action': 'conversations', 'user_id': userId.toString()});

  /// ห้องแชททั้งหมดที่ผูกกับ admin คนนี้ (action=admin_conversations)
  static Future<Map<String, dynamic>> getAdminConversations(int adminId) =>
      _get({'action': 'admin_conversations', 'admin_id': adminId.toString()});

  /// สร้าง (หรือดึงห้องเดิมถ้ามีอยู่แล้ว) ห้องแชทระหว่าง user กับ admin
  /// itemId ใส่เมื่อแชทผูกกับรายการของหาย/ของพบเรื่องใดเรื่องหนึ่งโดยเฉพาะ
  static Future<Map<String, dynamic>> createConversation({
    required int userId,
    required int adminId,
    int? itemId,
  }) => _post('create_conversation', {
    'user_id': userId.toString(),
    'admin_id': adminId.toString(),
    if (itemId != null) 'item_id': itemId.toString(),
  });

  /// ข้อความทั้งหมดในห้อง (action=messages)
  static Future<Map<String, dynamic>> getMessages(int conversationId) => _get({
    'action': 'messages',
    'conversation_id': conversationId.toString(),
  });

  /// ส่งข้อความ/รูป (action=send_message)
  static Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required int senderId,
    String message = '',
    String imageUrl = '',
  }) => _post('send_message', {
    'conversation_id': conversationId.toString(),
    'sender_id': senderId.toString(),
    'message': message,
    'image_url': imageUrl,
  });

  /// แอดมินคนแรกในระบบ ใช้ให้ฝั่ง user เริ่มแชทได้โดยไม่ต้องเลือกเอง
  static Future<Map<String, dynamic>> getDefaultAdmin() =>
      _get({'action': 'get_default_admin'});

  // =====================================================
  // CHAT: User <-> User (นัดรับของ หลัง claim ได้รับอนุมัติ)
  // =====================================================

  /// เปิด (หรือดึงห้องเดิมถ้ามีอยู่แล้ว) ห้องแชทนัดรับของ / คุยกับผู้แจ้ง
  /// action=open_item_chat (ส่ง claimId หรือ itemId)
  static Future<Map<String, dynamic>> openItemChat({
    int? claimId,
    int? itemId,
    required int userId,
  }) => _post('open_item_chat', {
    if (claimId != null && claimId > 0) 'claim_id': claimId.toString(),
    if (itemId != null && itemId > 0) 'item_id': itemId.toString(),
    'user_id': userId.toString(),
  });

  /// ห้องแชทนัดรับของทั้งหมดของ user คนนี้ (action=item_chats)
  static Future<Map<String, dynamic>> getItemChats(int userId) =>
      _get({'action': 'item_chats', 'user_id': userId.toString()});

  /// ข้อความทั้งหมดในห้องแชทนัดรับของ (action=item_chat_messages)
  static Future<Map<String, dynamic>> getItemChatMessages(int itemChatId) =>
      _get({
        'action': 'item_chat_messages',
        'item_chat_id': itemChatId.toString(),
      });

  /// ส่งข้อความ/รูปในห้องแชทนัดรับของ (action=send_item_chat_message)
  static Future<Map<String, dynamic>> sendItemChatMessage({
    required int itemChatId,
    required int senderId,
    String message = '',
    String imageUrl = '',
  }) => _post('send_item_chat_message', {
    'item_chat_id': itemChatId.toString(),
    'sender_id': senderId.toString(),
    'message': message,
    'image_url': imageUrl,
  });

  // =====================================================
  // CONFIRM RETURN (ผู้พบของยืนยันคืนของสำเร็จด้วยตัวเอง)
  // =====================================================

  /// ผู้พบของ (finder) ยืนยันว่าคืนของสำเร็จแล้ว
  /// action=confirm_return (POST) → เปลี่ยน status item เป็น 'returned'
  static Future<Map<String, dynamic>> confirmReturn({
    required int itemId,
    required int userId,
  }) => _post('confirm_return', {
    'item_id': itemId.toString(),
    'user_id': userId.toString(),
  });

  /// เจ้าของของหาย (owner) ยืนยันว่าได้รับของคืนแล้ว
  /// action=confirm_received (POST) → เปลี่ยน status item เป็น 'returned'
  static Future<Map<String, dynamic>> confirmReceived({
    required int itemId,
    required int userId,
  }) => _post('confirm_received', {
    'item_id': itemId.toString(),
    'user_id': userId.toString(),
  });

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  /// ดึงการแจ้งเตือนของ user (action=notifications)
  static Future<Map<String, dynamic>> getNotifications(int userId) =>
      _get({'action': 'notifications', 'user_id': userId.toString()});

  /// ทำเครื่องหมายว่าอ่านแล้วทั้งหมด (action=mark_notifications_read)
  static Future<Map<String, dynamic>> markNotificationsRead(int userId) =>
      _post('mark_notifications_read', {'user_id': userId.toString()});
}
