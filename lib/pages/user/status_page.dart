import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../shared/chat_room_page.dart';

/// หน้า "ติดตามสถานะ" ของผู้ใช้เอง
/// แท็บ 1: รายการของหาย/ของพบที่ฉันแจ้ง (my_items)
/// แท็บ 2: คำขอรับของที่ฉันยื่นไว้ (my_claims)
class StatusPage extends StatefulWidget {
  final int userId;

  const StatusPage({super.key, required this.userId});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage>
    with SingleTickerProviderStateMixin {
  static const Color kBlue = Color(0xFF2563EB);
  static const Color kText = Color(0xFF1E293B);
  static const Color kGrey = Color(0xFF94A3B8);
  static const Color kGreen = Color(0xFF16A34A);
  static const Color kRed = Color(0xFFDC2626);

  late TabController tabController;

  bool loadingItems = true;
  bool loadingClaims = true;
  List<Map<String, dynamic>> myItems = [];
  List<Map<String, dynamic>> myClaims = [];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadItems(), _loadClaims()]);
  }

  Future<void> _loadItems() async {
    final res = await ApiService.getMyItems(widget.userId);
    if (!mounted) return;
    setState(() {
      loadingItems = false;
      if (res['success'] == true && res['data'] is List) {
        myItems = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

  Future<void> _loadClaims() async {
    final res = await ApiService.getMyClaims(widget.userId);
    if (!mounted) return;
    setState(() {
      loadingClaims = false;
      if (res['success'] == true && res['data'] is List) {
        myClaims = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kText,
        title: const Text(
          'ติดตามสถานะของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
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
            Tab(text: 'รายการที่แจ้ง'),
            Tab(text: 'คำขอรับของ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [_itemsTab(), _claimsTab()],
      ),
    );
  }

  // =====================================================
  // TAB 1: รายการที่แจ้ง (ของหาย / ของพบ)
  // =====================================================

  Widget _itemsTab() {
    if (loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }
    if (myItems.isEmpty) {
      return _empty('คุณยังไม่เคยแจ้งรายการ');
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myItems.length,
        itemBuilder: (_, i) => _itemCard(myItems[i]),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final isFound = item['type'] == 'found';
    final img = _firstImage(item['image_url']);

    // ลำดับขั้นของรายการ (ไม่รวม rejected ซึ่งเป็นทางตัน)
    // สำหรับของหาย (lost) ไม่ต้องรอแอดมินอนุมัติ ประกาศทันที
    final steps = isFound
        ? ['pending', 'approved', 'claimed', 'returned']
        : ['pending', 'claimed', 'returned'];
    final stepLabels = isFound
        ? ['ส่งเรื่องแล้ว', 'แอดมินอนุมัติ', 'มีผู้ยื่นขอรับ', 'คืนสำเร็จ']
        : ['ประกาศของหายแล้ว', 'มีผู้ติดต่อ/แจ้งพบ', 'ได้รับของคืนแล้ว'];

    final rejected = status == 'rejected';
    int currentStep = 0;
    if (!rejected) {
      if (isFound) {
        currentStep = steps.indexOf(status);
        if (currentStep < 0) currentStep = 0;
      } else {
        // ของหาย: pending คือขั้น 0 (ประกาศแล้ว), claimed คือขั้น 1, returned คือขั้น 2
        if (status == 'returned') {
          currentStep = 2;
        } else if (status == 'claimed' || status == 'approved') {
          currentStep = 1;
        } else {
          currentStep = 0;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  width: 56,
                  height: 56,
                  child: img.isEmpty
                      ? Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                            size: 22,
                          ),
                        )
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isFound
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFound ? 'แจ้งพบของ' : 'แจ้งของหาย',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isFound
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['item_name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'แจ้งเมื่อ ${_formatDate(item['created_at'])}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _statusBadge(
                rejected ? 'ไม่อนุมัติ' : stepLabels[currentStep],
                rejected ? kRed : (status == 'returned' ? kGreen : kBlue),
              ),
            ],
          ),
          const SizedBox(height: 14),
          rejected ? _rejectedNote() : _timeline(stepLabels, currentStep),
          // ปุ่มสำหรับผู้พบของ: เมื่อมีคนยื่นสิทธิ์ (claimed) ให้ยืนยันคืนของด้วยตัวเอง
          if (isFound && status == 'claimed') ...[
            const SizedBox(height: 12),
            _openChatButton(
              claimId: int.tryParse(item['approved_claim_id']?.toString() ?? '0'),
              itemId: int.tryParse(item['id']?.toString() ?? '0'),
              label: 'แชทกับผู้ยื่นสิทธิ์',
            ),
            const SizedBox(height: 8),
            _confirmReturnButton(item),
          ],
          // ปุ่มสำหรับเจ้าของของหาย: เมื่อมีคนติดต่อแล้ว ให้ยืนยันว่าได้รับของคืน
          if (!isFound && (status == 'claimed' || status == 'approved')) ...[
            const SizedBox(height: 12),
            _confirmReceivedButton(item),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // TAB 2: คำขอรับของ (claims)
  // =====================================================

  Widget _claimsTab() {
    if (loadingClaims) {
      return const Center(child: CircularProgressIndicator());
    }
    if (myClaims.isEmpty) {
      return _empty('คุณยังไม่เคยยื่นขอรับของ');
    }

    return RefreshIndicator(
      onRefresh: _loadClaims,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myClaims.length,
        itemBuilder: (_, i) => _claimCard(myClaims[i]),
      ),
    );
  }

  Widget _claimCard(Map<String, dynamic> claim) {
    final status = claim['status']?.toString() ?? 'pending';
    final img = _firstImage(claim['image_url']);

    const steps = ['pending', 'approved'];
    const stepLabels = ['ส่งคำขอแล้ว', 'แอดมินตรวจสอบและยืนยัน'];
    final rejected = status == 'rejected';
    final currentStep = rejected ? 0 : steps.indexOf(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  width: 56,
                  height: 56,
                  child: img.isEmpty
                      ? Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                            size: 22,
                          ),
                        )
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
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
                    Text(
                      claim['item_name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ยื่นขอเมื่อ ${_formatDate(claim['created_at'])}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _statusBadge(
                rejected ? 'ไม่อนุมัติ' : stepLabels[currentStep],
                rejected ? kRed : (status == 'approved' ? kGreen : kBlue),
              ),
            ],
          ),
          const SizedBox(height: 14),
          rejected
              ? _rejectedNote(claimStyle: true)
              : _timeline(stepLabels, currentStep),
          if ((claim['admin_note']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: kGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'หมายเหตุจากแอดมิน: ${claim['admin_note']}',
                      style: const TextStyle(fontSize: 11.5, color: kText),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status != 'rejected') ...[
            const SizedBox(height: 12),
            _openChatButton(
              claimId: int.tryParse(claim['id'].toString()) ?? 0,
              label: 'แชทนัดรับของกับผู้แจ้ง',
            ),
          ],
          // ปุ่มยืนยันรับของสำหรับผู้ยื่นคำขอ เมื่อคำขอได้รับการอนุมัติแล้ว
          // ตรวจทั้ง claim status และ item_status ให้แน่ใจว่า item พร้อมยืนยัน
          if ((status == 'approved' || status == 'claimed') &&
              ['claimed', 'approved'].contains(claim['item_status']?.toString())) ...[
            const SizedBox(height: 8),
            _confirmReceivedClaimButton(claim),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // SHARED WIDGETS
  // =====================================================

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
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

  Widget _rejectedNote({bool claimStyle = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, size: 16, color: kRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              claimStyle
                  ? 'คำขอนี้ไม่ผ่านการตรวจสอบจากแอดมิน'
                  : 'รายการนี้ไม่ผ่านการตรวจสอบจากแอดมิน',
              style: const TextStyle(fontSize: 11.5, color: kRed),
            ),
          ),
        ],
      ),
    );
  }

  /// เส้นไทม์ไลน์แนวนอน แสดงขั้นตอนที่ทำสำเร็จแล้ว (ทึบ) กับยังไม่ถึง (จาง)
  Widget _timeline(List<String> labels, int currentStep) {
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i <= currentStep;
        final isLast = i == labels.length - 1;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: done ? kBlue : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done ? Icons.check : Icons.circle,
                      color: Colors.white,
                      size: done ? 13 : 6,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentStep
                            ? kBlue
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                textAlign: TextAlign.left,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: done ? FontWeight.bold : FontWeight.normal,
                  color: done ? kText : kGrey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// ปุ่มยืนยันคืนของสำเร็จ (เฉพาะผู้พบของ เมื่อ status=claimed)
  Widget _confirmReturnButton(Map<String, dynamic> item) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _confirmReturn(item),
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: const Text('ยืนยันคืนของสำเร็จ', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  /// ปุ่มยืนยันรับของสำหรับเจ้าของของหาย (lost item owner)
  Widget _confirmReceivedButton(Map<String, dynamic> item) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _confirmReceived(item),
        icon: const Icon(Icons.inventory_2_outlined, size: 16),
        label: const Text('ได้รับของแล้ว', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  /// ปุ่มยืนยันรับของสำหรับผู้ยื่นคำขอ (claim side)
  Widget _confirmReceivedClaimButton(Map<String, dynamic> claim) {
    // ดึง item_id จาก claim
    final itemId = int.tryParse(claim['item_id']?.toString() ?? '0') ?? 0;
    if (itemId <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _confirmReceivedFromClaim(claim),
        icon: const Icon(Icons.inventory_2_outlined, size: 16),
        label: const Text('ได้รับของแล้ว', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _confirmReceived(Map<String, dynamic> item) async {
    final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    if (itemId <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันได้รับของแล้ว', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'ยืนยันว่าคุณได้รับ "${item['item_name'] ?? 'รายการนี้'}" คืนเรียบร้อยแล้ว?\nรายการจะถูกย้ายไปยังประวัติและหายไปจากหน้าหลัก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.confirmReceived(
      itemId: itemId,
      userId: widget.userId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 ยืนยันได้รับของคืนเรียบร้อยแล้ว!'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ไม่สามารถยืนยันได้ในขณะนี้'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _confirmReceivedFromClaim(Map<String, dynamic> claim) async {
    final itemId = int.tryParse(claim['item_id']?.toString() ?? '0') ?? 0;
    if (itemId <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันได้รับของแล้ว', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'ยืนยันว่าคุณได้รับ "${claim['item_name'] ?? 'รายการนี้'}" คืนเรียบร้อยแล้ว?\nรายการจะถูกย้ายไปยังประวัติและหายไปจากหน้าหลัก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.confirmReceived(
      itemId: itemId,
      userId: widget.userId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 ยืนยันได้รับของคืนเรียบร้อยแล้ว!'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadClaims();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ไม่สามารถยืนยันได้ในขณะนี้'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _confirmReturn(Map<String, dynamic> item) async {
    final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    if (itemId <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันคืนของสำเร็จ', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'ยืนยันว่าคืน "${item['item_name'] ?? 'รายการนี้'}" ให้เจ้าของเรียบร้อยแล้ว?\nรายการจะถูกย้ายไปยังประวัติและหายไปจากหน้าหลัก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.confirmReturn(
      itemId: itemId,
      userId: widget.userId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 ยืนยันคืนของสำเร็จเรียบร้อยแล้ว!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // รีโหลดรายการให้อัปเดตสถานะ
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ไม่สามารถยืนยันได้ในขณะนี้'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// ปุ่มเปิดห้องแชทนัดรับของ ใช้ทั้งฝั่งผู้แจ้งและผู้ยื่นขอรับ
  /// เรียก open_item_chat ด้วย claimId หรือ itemId แล้วพาไปหน้า ChatRoomPage แบบ isPeerChat
  Widget _openChatButton({int? claimId, int? itemId, required String label}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openPeerChat(claimId: claimId, itemId: itemId),
        icon: const Icon(Icons.handshake_outlined, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF16A34A),
          side: const BorderSide(color: Color(0xFF16A34A)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _openPeerChat({int? claimId, int? itemId}) async {
    final cId = claimId ?? 0;
    final iId = itemId ?? 0;
    if (cId <= 0 && iId <= 0) return;

    final res = await ApiService.openItemChat(
      claimId: cId > 0 ? cId : null,
      itemId: iId > 0 ? iId : null,
      userId: widget.userId,
    );

    if (!mounted) return;

    if (res['success'] != true || res['data'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'เปิดห้องแชทไม่สำเร็จ'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    final data = res['data'];
    final itemChatId = int.tryParse(data['item_chat_id'].toString()) ?? 0;
    final peerName = data['peer_name']?.toString() ?? 'ผู้ใช้งาน';
    final itemName = data['item_name']?.toString() ?? '';

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
  }

  Widget _empty(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
