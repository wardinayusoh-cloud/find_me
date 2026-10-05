import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../shared/pattani_map_picker_page.dart';

/// หน้า "แจ้งเรื่องของหาย / พบของ"
/// ใช้แท็บเดียวสลับได้ทั้งแจ้งของหาย (lost) และแจ้งพบของ (found)
class ReportItemPage extends StatefulWidget {
  final dynamic userData;
  final bool startAsFound;

  /// ส่งรายการเดิม (จาก my_items) มาเพื่อเปิดหน้าในโหมด "แก้ไข"
  /// ถ้าเป็น null = โหมดแจ้งใหม่ตามเดิม
  final Map<String, dynamic>? editItem;

  const ReportItemPage({
    super.key,
    required this.userData,
    this.startAsFound = false,
    this.editItem,
  });

  @override
  State<ReportItemPage> createState() => _ReportItemPageState();
}

class _ReportItemPageState extends State<ReportItemPage> {
  // =====================================================
  // ประเภท: false = แจ้งของหาย (lost), true = แจ้งพบของ (found)
  // =====================================================
  late bool isFound;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  static const int maxImages = 5;

  final itemNameController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  List<Map<String, dynamic>> categories = [];
  int? selectedCategoryId;
  bool loadingCategories = true;

  String? selectedProvince;

  DateTime? lostDate; // ใช้เฉพาะแท็บ "แจ้งของหาย"

  bool isSubmitting = false;

  // =====================================================
  // โหมดแก้ไข
  // =====================================================
  bool get isEdit => widget.editItem != null;

  /// รูปเดิมที่อยู่บน server แล้ว (แสดงก่อนรูปที่เลือกใหม่)
  final List<String> _existingUrls = [];

  int get _totalImages => _existingUrls.length + _images.length;

  // =====================================================
  // จำกัดขอบเขตพื้นที่ให้ใช้ได้เฉพาะจังหวัดปัตตานีเท่านั้น
  // (ตัดรายชื่อ 77 จังหวัดออก เหลือตัวเลือกเดียว)
  // =====================================================
  static const List<Map<String, String>> provinces = [
    {'name': 'ปัตตานี', 'region': 'ภาคใต้'},
  ];

  @override
  void initState() {
    super.initState();
    isFound = widget.startAsFound;
    if (isEdit) _prefillFromItem(widget.editItem!);
    // แอปนี้ให้บริการเฉพาะจังหวัดปัตตานี จึงเลือกให้อัตโนมัติ
    selectedProvince = provinces.first['name'];
    _loadCategories();
  }

  /// เติมข้อมูลเดิมลงฟอร์ม (โหมดแก้ไข)
  void _prefillFromItem(Map<String, dynamic> it) {
    isFound = it['type']?.toString() == 'found';
    itemNameController.text = it['item_name']?.toString() ?? '';
    descriptionController.text = it['description']?.toString() ?? '';

    // สถานที่ถูกต่อท้ายด้วย "จ.ปัตตานี" ตอนแจ้ง จึงตัดออกก่อนแสดงในช่อง
    final loc = it['location']?.toString() ?? '';
    final m = RegExp(r'\s*จ\.\S+\s*$').firstMatch(loc);
    locationController.text = (m != null ? loc.substring(0, m.start) : loc)
        .trim();

    final d = it['lost_found_date']?.toString() ?? '';
    if (d.length >= 10) lostDate = DateTime.tryParse(d.substring(0, 10));

    // image_url เก็บหลายรูปคั่นด้วย ","
    _existingUrls.addAll(
      (it['image_url']?.toString() ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => ApiService.imageUrl(e)),
    );
  }

  Future<void> _loadCategories() async {
    final result = await ApiService.getCategories();

    if (!mounted) return;

    setState(() {
      loadingCategories = false;

      if (result['success'] == true && result['data'] != null) {
        categories = List<Map<String, dynamic>>.from(
          (result['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );

        if (isEdit) {
          final cid = int.tryParse(
            widget.editItem!['category_id']?.toString() ?? '',
          );
          final exists = categories.any(
            (c) => int.tryParse(c['id'].toString()) == cid,
          );
          selectedCategoryId = exists ? cid : null;
        } else if (categories.isNotEmpty) {
          selectedCategoryId = int.tryParse(categories.first['id'].toString());
        }
      }
    });
  }

  // =====================================================
  // เลือกรูปภาพ
  // =====================================================

  Future<void> _pickImage(ImageSource source) async {
    if (_totalImages >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เพิ่มรูปภาพได้สูงสุด $maxImages รูป')),
      );
      return;
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() {
          _images.add(picked);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกรูปภาพได้: $e')));
    }
  }

  /// index รวม: รูปเดิมมาก่อน แล้วตามด้วยรูปที่เลือกใหม่
  void _removeImage(int index) {
    setState(() {
      if (index < _existingUrls.length) {
        _existingUrls.removeAt(index);
      } else {
        _images.removeAt(index - _existingUrls.length);
      }
    });
  }

  Widget _imageThumb(int index) {
    final isExisting = index < _existingUrls.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isExisting
          ? Image.network(
              _existingUrls[index],
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 84,
                height: 84,
                color: const Color(0xFFE2E8F0),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              ),
            )
          : kIsWeb
          ? Image.network(
              _images[index - _existingUrls.length].path,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            )
          : Image.file(
              File(_images[index - _existingUrls.length].path),
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
    );
  }

  /// แถบบอกประเภทรายการ (โหมดแก้ไขเปลี่ยนประเภทไม่ได้)
  Widget _editBanner() {
    const amber = Color(0xFFB45309);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFound ? Icons.check_circle_outline : Icons.search,
                size: 18,
                color: amber,
              ),
              const SizedBox(width: 6),
              Text(
                isFound ? 'ประเภท: แจ้งพบของ' : 'ประเภท: ถามหาของหาย',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'หลังบันทึก รายการจะกลับเป็น "รอตรวจสอบ" เพื่อให้แอดมินตรวจสอบอีกครั้ง',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // เลือกวันที่ทำหาย (ใช้เฉพาะแท็บของหาย)
  // =====================================================

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          (lostDate != null &&
              !lostDate!.isBefore(DateTime(2020)) &&
              !lostDate!.isAfter(DateTime.now()))
          ? lostDate!
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        lostDate = picked;
      });
    }
  }

  // =====================================================
  // ส่งข้อมูล
  // =====================================================

  Future<void> _submit() async {
    if (_totalImages == 0) {
      _showError('กรุณาเพิ่มรูปภาพอย่างน้อย 1 รูป');
      return;
    }

    if (itemNameController.text.trim().isEmpty) {
      _showError('กรุณากรอกชื่อสิ่งของ');
      return;
    }

    if (selectedCategoryId == null) {
      _showError('กรุณาเลือกหมวดหมู่สิ่งของ');
      return;
    }

    if (selectedProvince == null) {
      _showError('กรุณาเลือกจังหวัด');
      return;
    }

    if (locationController.text.trim().isEmpty) {
      _showError(
        isFound ? 'กรุณากรอกสถานที่ที่พบ' : 'กรุณากรอกสถานที่ที่ทำหาย',
      );
      return;
    }

    if (!isFound && lostDate == null) {
      _showError('กรุณาเลือกวันที่ทำหาย');
      return;
    }

    final userId = int.tryParse(widget.userData?['id']?.toString() ?? '');

    if (userId == null) {
      _showError('ไม่พบข้อมูลผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // ---------------------------------------------------
      // 1) อัปโหลดรูปภาพทั้งหมดก่อน แล้วรวม URL ด้วย ","
      // ---------------------------------------------------

      // รูปเดิม (โหมดแก้ไข) มาก่อน แล้วต่อด้วยรูปที่อัปโหลดใหม่
      final List<String> uploadedUrls = [..._existingUrls];

      for (final image in _images) {
        final uploadResult = await ApiService.uploadImage(image);

        if (uploadResult['success'] == true &&
            uploadResult['data'] != null &&
            uploadResult['data']['url'] != null) {
          uploadedUrls.add(uploadResult['data']['url'].toString());
        }
      }

      // โหมดแก้ไข: ถ้ามีรูปไหนอัปโหลดไม่สำเร็จ ให้หยุด (กันรูปหายเงียบๆ)
      if (isEdit && uploadedUrls.length < _totalImages) {
        if (!mounted) return;
        setState(() {
          isSubmitting = false;
        });
        _showError('อัปโหลดรูปภาพบางรูปไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
        return;
      }

      // ---------------------------------------------------
      // 2) ส่งข้อมูลรายการไปยัง API (action=add_item)
      // ---------------------------------------------------

      final province = provinces.firstWhere(
        (p) => p['name'] == selectedProvince,
      );

      final locationText =
          '${locationController.text.trim()} จ.${province['name']}';

      // แจ้งพบของ: ตอนแจ้งใหม่ใช้วันนี้ / ตอนแก้ไขคงวันที่เดิมไว้
      final originalDate =
          widget.editItem?['lost_found_date']?.toString() ?? '';
      final dateToSend = isFound
          ? (isEdit && originalDate.length >= 10
                ? originalDate.substring(0, 10)
                : DateTime.now().toIso8601String().split('T').first)
          : lostDate!.toIso8601String().split('T').first;

      final Map<String, dynamic> result = isEdit
          ? await ApiService.updateItem(
              itemId:
                  int.tryParse(widget.editItem!['id']?.toString() ?? '') ?? 0,
              userId: userId,
              categoryId: selectedCategoryId!,
              itemName: itemNameController.text.trim(),
              description: descriptionController.text.trim(),
              color: widget.editItem!['color']?.toString() ?? '',
              location: locationText,
              lostFoundDate: dateToSend,
              imageUrl: uploadedUrls.join(','),
            )
          : await ApiService.createItem(
              userId: userId,
              categoryId: selectedCategoryId!,
              type: isFound ? 'found' : 'lost',
              itemName: itemNameController.text.trim(),
              description: descriptionController.text.trim(),
              location: locationText,
              lostFoundDate: dateToSend,
              imageUrl: uploadedUrls.join(','),
            );

      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? (result['message']?.toString() ?? 'แก้ไขรายการสำเร็จ')
                  : (isFound
                        ? 'แจ้งพบของสำเร็จ รอ Admin ตรวจสอบ'
                        : 'แจ้งของหายสำเร็จ ประกาศขึ้นระบบแล้ว'),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // โหมดแก้ไขส่ง true กลับ เพื่อให้หน้าโปรไฟล์โหลดรายการใหม่
        Navigator.pop(context, isEdit ? true : null);
      } else {
        _showError(result['message']?.toString() ?? 'ไม่สามารถบันทึกข้อมูลได้');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      _showError('เกิดข้อผิดพลาด: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    itemNameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xfff7f4ff),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================================================
              // HEADER CARD
              // =================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: brandBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'แก้ไขรายการ' : 'แจ้งเรื่องของหาย / พบของ',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            isEdit
                                ? 'แก้ไขข้อมูลแล้วกดบันทึก'
                                : 'กรอกข้อมูลให้ครบเพื่อแจ้งของหายหรือของที่พบ',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xfff1f1f6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // =================================================
              // TABS: ของหาย / พบของ
              // =================================================
              if (!isEdit) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xffeef0fb),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          label: 'ถามหาของหาย',
                          icon: Icons.search,
                          selected: !isFound,
                          onTap: () => setState(() => isFound = false),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _tabButton(
                          label: 'แจ้งพบของ',
                          icon: Icons.check_circle_outline,
                          selected: isFound,
                          onTap: () => setState(() => isFound = true),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
              ] else ...[
                _editBanner(),
                const SizedBox(height: 18),
              ],

              // =================================================
              // PHOTO SECTION
              // =================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfff3f2ff),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isFound
                              ? Icons.add_a_photo_outlined
                              : Icons.photo_camera_back_outlined,
                          size: 18,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isFound
                                ? 'รูปถ่ายของที่เก็บได้ชัดเจน *'
                                : 'รูปภาพของที่ทำหาย *',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_totalImages/$maxImages รูป',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFound
                          ? 'ถ่ายภาพให้ชัดเจนเห็นรายละเอียด (ไม่ต้องถ่ายติดใบหน้าคนอื่น)'
                          : 'ใส่รูปสิ่งของที่ทำหายเพื่อให้ผู้พบจำได้ง่ายขึ้น',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('ถ่ายภาพ'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: brandBlue,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 18,
                            ),
                            label: const Text('เลือกจากอัลบั้ม'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_totalImages == 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'ยังไม่ได้เพิ่มรูปภาพ กดปุ่มด้านบนเพื่อเพิ่มรูป',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                    else
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _totalImages,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _imageThumb(index),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // =================================================
              // ชื่อสิ่งของ
              // =================================================
              const Text(
                'ชื่อสิ่งของ *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: itemNameController,
                decoration: _fieldDecoration(
                  hint: 'เช่น กระเป๋าสตางค์ Coach, กุญแจรถ',
                ),
              ),

              const SizedBox(height: 16),

              // =================================================
              // หมวดหมู่ / จังหวัด
              // =================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'หมวดหมู่สิ่งของ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        loadingCategories
                            ? Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xfff0f0f7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<int>(
                                value: selectedCategoryId,
                                isExpanded: true,
                                decoration: _fieldDecoration(
                                  hint: 'เลือกหมวดหมู่',
                                ),
                                items: categories.map((c) {
                                  return DropdownMenuItem<int>(
                                    value: int.tryParse(c['id'].toString()),
                                    child: Text(
                                      c['name']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedCategoryId = value;
                                  });
                                },
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'จังหวัด (ให้บริการเฉพาะปัตตานี) *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // จำกัดพื้นที่ให้บริการเฉพาะจังหวัดปัตตานี
                        // จึงตรึงค่าไว้ ไม่ให้ผู้ใช้เปลี่ยนจังหวัดอื่น
                        IgnorePointer(
                          child: DropdownButtonFormField<String>(
                            value: selectedProvince,
                            isExpanded: true,
                            decoration: _fieldDecoration(hint: 'ปัตตานี'),
                            items: provinces.map((p) {
                              return DropdownMenuItem<String>(
                                value: p['name'],
                                child: Text(
                                  p['name']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // =================================================
              // วันที่ทำหาย (เฉพาะแท็บของหาย)
              // =================================================
              if (!isFound) ...[
                const Text(
                  'วันที่ทำหาย *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                      hint: 'เลือกวันที่',
                      icon: Icons.calendar_month_outlined,
                    ),
                    child: Text(
                      lostDate == null
                          ? 'เลือกวันที่'
                          : '${lostDate!.day}/${lostDate!.month}/${lostDate!.year}',
                      style: TextStyle(
                        color: lostDate == null ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // =================================================
              // สถานที่
              // =================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFound ? 'สถานที่ ที่พบ *' : 'สถานที่ ที่ทำหาย *',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final selected = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PattaniMapPickerPage(
                            initialLocation: locationController.text.trim(),
                          ),
                        ),
                      );
                      if (selected != null && selected.isNotEmpty) {
                        setState(() {
                          locationController.text = selected;
                        });
                      }
                    },
                    icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                    label: const Text(
                      'ปักหมุดบนแผนที่ปัตตานี',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: locationController,
                decoration: _fieldDecoration(
                  hint: 'เช่น ม.อ.ปัตตานี, ตลาดโต้รุ่ง, หาดตะโละกาโปร์',
                  icon: Icons.location_on_outlined,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: 'ปักหมุดบนแผนที่ปัตตานี',
                    icon: const Icon(Icons.pin_drop, color: Color(0xFF2563EB), size: 22),
                    onPressed: () async {
                      final selected = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PattaniMapPickerPage(
                            initialLocation: locationController.text.trim(),
                          ),
                        ),
                      );
                      if (selected != null && selected.isNotEmpty) {
                        setState(() {
                          locationController.text = selected;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =================================================
              // รายละเอียดเพิ่มเติม
              // =================================================
              const Text(
                'รายละเอียดเพิ่มเติม',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: _fieldDecoration(
                  hint: 'ระบุลักษณะ หรือข้อความที่อยากฝากเพิ่มเติม...',
                ),
              ),

              const SizedBox(height: 22),

              // =================================================
              // ปุ่มส่งข้อมูล
              // =================================================
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    isSubmitting
                        ? (isEdit ? 'กำลังบันทึก...' : 'กำลังส่งข้อมูล...')
                        : (isEdit
                              ? 'บันทึกการแก้ไข'
                              : 'บันทึกและส่งข้อมูลแจ้งของ'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: const Color(0xFF2563EB), width: 1.4)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? const Color(0xFF2563EB) : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? const Color(0xFF2563EB) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: const Color(0xfff3f4fa),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
      ),
    );
  }
}
