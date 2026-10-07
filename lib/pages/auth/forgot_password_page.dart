import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool showNewPassword = false;
  bool showConfirmPassword = false;
  bool isLoading = false;

  // =====================================================
  // RESET PASSWORD
  // =====================================================

  Future<void> resetPassword() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // ตรวจสอบช่องว่าง
    if (username.isEmpty ||
        email.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ตรวจสอบรูปแบบ email
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รูปแบบอีเมลไม่ถูกต้อง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ตรวจสอบความยาวรหัสผ่าน
    if (newPassword.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านต้องมีอย่างน้อย 4 ตัวอักษร'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ตรวจสอบรหัสผ่านตรงกัน
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านไม่ตรงกัน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.resetPassword(
        username: username,
        email: email,
        newPassword: newPassword,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (result['success'] == true) {
        // สำเร็จ — แสดง dialog แล้วกลับหน้า login
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            title: const Text('เปลี่ยนรหัสผ่านสำเร็จ'),
            content: const Text(
              'กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่ของคุณ',
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // ปิด dialog
                    Navigator.of(context).pop(); // กลับหน้า login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'กลับไปเข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'ไม่พบบัญชีที่ตรงกับข้อมูลที่กรอก',
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
    usernameController.dispose();
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f5ff),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ลืมรหัสผ่าน',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // =================================================
              // ICON
              // =================================================

              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_reset,
                  color: Color(0xFF2563EB),
                  size: 45,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'รีเซ็ตรหัสผ่าน',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'กรอก Username และ Email ที่ใช้สมัคร\nเพื่อยืนยันตัวตนและตั้งรหัสผ่านใหม่',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 35),

              // =================================================
              // USERNAME
              // =================================================

              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Colors.grey),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                  prefixIcon: const Icon(Icons.person),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Colors.grey.shade400,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // EMAIL
              // =================================================

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email ที่ใช้สมัคร',
                  labelStyle: const TextStyle(color: Colors.grey),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                  prefixIcon: const Icon(Icons.email),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Colors.grey.shade400,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // NEW PASSWORD
              // =================================================

              TextField(
                controller: newPasswordController,
                obscureText: !showNewPassword,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  labelStyle: const TextStyle(color: Colors.grey),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showNewPassword = !showNewPassword;
                      });
                    },
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Colors.grey.shade400,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // CONFIRM PASSWORD
              // =================================================

              TextField(
                controller: confirmPasswordController,
                obscureText: !showConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  labelStyle: const TextStyle(color: Colors.grey),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showConfirmPassword = !showConfirmPassword;
                      });
                    },
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Colors.grey.shade400,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // RESET BUTTON
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'เปลี่ยนรหัสผ่าน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // BACK TO LOGIN
              // =================================================

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'กลับไปหน้าเข้าสู่ระบบ',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
