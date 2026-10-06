import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../shared/pattani_map_picker_page.dart';

class ReportLostPage extends StatefulWidget {
  final String username;

  const ReportLostPage({
    super.key,
    required this.username,
  });

  @override
  State<ReportLostPage> createState() => _ReportLostPageState();
}

class _ReportLostPageState extends State<ReportLostPage> {
  final itemNameController = TextEditingController();
  final colorController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedCategory;
  DateTime? lostDate;

  bool isLoading = false;

  final List<String> categories = [
    'โทรศัพท์มือถือ',
    'กระเป๋า',
    'กระเป๋าสตางค์',
    'กุญแจ',
    'เอกสาร',
    'อุปกรณ์อิเล็กทรอนิกส์',
    'เสื้อผ้า',
    'บัตรนักศึกษา',
    'เครื่องเขียน',
    'อื่น ๆ',
  ];

  Future<void> selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        lostDate = picked;
      });
    }
  }

  Future<void> submitLostItem() async {
    if (itemNameController.text.trim().isEmpty ||
        selectedCategory == null ||
        colorController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        lostDate == null ||
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.createLostItem(
        username: widget.username,
        itemName: itemNameController.text.trim(),
        category: selectedCategory!,
        color: colorController.text.trim(),
        location: locationController.text.trim(),
        lostDate: lostDate!.toIso8601String().split('T').first,
        description: descriptionController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('แจ้งของหายสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'ไม่สามารถแจ้งของหายได้',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    itemNameController.dispose();
    colorController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f4ff),

      appBar: AppBar(
        title: const Text(
          'แจ้งของหาย',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // หัวข้อ
            const Text(
              'รายละเอียดของที่หาย',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'กรุณากรอกข้อมูลเกี่ยวกับสิ่งของที่คุณทำหาย',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            // ชื่อสิ่งของ
            TextField(
              controller: itemNameController,
              decoration: inputDecoration(
                label: 'ชื่อสิ่งของ',
                icon: Icons.inventory_2_outlined,
              ),
            ),

            const SizedBox(height: 15),

            // หมวดหมู่
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: inputDecoration(
                label: 'หมวดหมู่',
                icon: Icons.category_outlined,
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 15),

            // สี
            TextField(
              controller: colorController,
              decoration: inputDecoration(
                label: 'สีของสิ่งของ',
                icon: Icons.color_lens_outlined,
              ),
            ),

            const SizedBox(height: 15),

            // สถานที่
            TextField(
              controller: locationController,
              decoration: inputDecoration(
                label: 'สถานที่ที่ทำหาย',
                icon: Icons.location_on_outlined,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: 'ปักหมุดบนแผนที่ปัตตานี',
                  icon: const Icon(Icons.pin_drop, color: Color(0xFF2563EB)),
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

            const SizedBox(height: 15),

            // วันที่
            InkWell(
              onTap: selectDate,
              child: InputDecorator(
                decoration: inputDecoration(
                  label: 'วันที่ทำหาย',
                  icon: Icons.calendar_month_outlined,
                ),
                child: Text(
                  lostDate == null
                      ? 'เลือกวันที่'
                      : '${lostDate!.day}/${lostDate!.month}/${lostDate!.year}',
                  style: TextStyle(
                    color: lostDate == null
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // รายละเอียด
            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: inputDecoration(
                label: 'รายละเอียดเพิ่มเติม',
                icon: Icons.description_outlined,
              ),
            ),

            const SizedBox(height: 25),

            // ปุ่มแจ้ง
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : submitLostItem,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  isLoading ? 'กำลังส่งข้อมูล...' : 'แจ้งของหาย',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}