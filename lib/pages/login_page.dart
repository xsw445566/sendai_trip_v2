import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _isLogin = true;

  // 1. 訪客登入邏輯
  Future<void> _signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("訪客登入失敗: $e")));
    }
  }

  // 2. Google 登入 (簡化邏輯，需配合 google_sign_in 套件)
  Future<void> _signInWithGoogle() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Google 登入功能需配置 SHA-1 指紋與套件")));
    // 實作代碼通常如下：
    // final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
    // final GoogleSignInAuthentication gAuth = await gUser!.authentication;
    // final credential = GoogleAuthProvider.credential(accessToken: gAuth.accessToken, idToken: gAuth.idToken);
    // await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailC.text.trim(),
          password: _passwordC.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailC.text.trim(),
          password: _passwordC.text.trim(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("錯誤: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // 深藍色背景
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(
                Icons.flight_takeoff,
                size: 80,
                color: Color(0xFFD4C5A9),
              ),
              const SizedBox(height: 10),
              const Text(
                "STARLUX JOURNEY",
                style: TextStyle(
                  color: Color(0xFFD4C5A9),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),

              // 登入表單卡片
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailC,
                      decoration: const InputDecoration(labelText: "電子郵件"),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordC,
                      decoration: const InputDecoration(labelText: "密碼"),
                      obscureText: true,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E8B6E),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isLogin ? "登入" : "註冊"),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin ? "沒有帳號？立即註冊" : "已有帳號？前往登入",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Text(
                "或者透過以下方式",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // 第三方登入按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialBtn(Icons.person_outline, "訪客登入", _signInAnonymously),
                  const SizedBox(width: 20),
                  _socialBtn(Icons.g_mobiledata, "Google", _signInWithGoogle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withAlpha(30),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
