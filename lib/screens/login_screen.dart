import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/disclaimer_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  int _step = 0; // 0: phone input, 1: captcha, 2: sms code
  bool _sendingSms = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _captchaCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.water_drop, size: 64, color: Colors.blue),
                const SizedBox(height: 8),
                const Text('云水', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('直饮水服务', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 32),
                _buildPhoneField(),
                const SizedBox(height: 16),
                if (_step >= 1) ...[
                  _buildCaptchaField(auth),
                  const SizedBox(height: 16),
                ],
                if (_step >= 2) ...[
                  _buildSmsField(),
                  const SizedBox(height: 16),
                ],
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
                  ),
                _buildButton(auth),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      decoration: const InputDecoration(
        labelText: '手机号',
        hintText: '请输入手机号',
        prefixIcon: Icon(Icons.phone_android),
        border: OutlineInputBorder(),
        counterText: '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildCaptchaField(AuthProvider auth) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _captchaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '图片验证码',
                  hintText: '请输入验证码',
                  prefixIcon: Icon(Icons.security),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: auth.loading ? null : () => auth.fetchCaptcha(),
              child: auth.captcha != null
                  ? Image.memory(
                      Uint8List.fromList(auth.captcha!.imageBytes),
                      width: 100,
                      height: 44,
                      fit: BoxFit.fill,
                    )
                  : Container(
                      width: 100,
                      height: 44,
                      color: Colors.grey[200],
                      child: auth.loading
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmsField() {
    return TextField(
      controller: _smsCtrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(
        labelText: '短信验证码',
        hintText: '请输入短信验证码',
        prefixIcon: Icon(Icons.sms),
        border: OutlineInputBorder(),
        counterText: '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildButton(AuthProvider auth) {
    final phoneValid = _phoneCtrl.text.length == 11;

    if (_step == 0) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: phoneValid && !auth.loading
              ? () async {
                  final ok = await auth.fetchCaptcha();
                  if (ok && mounted) setState(() => _step = 1);
                }
              : null,
          child: auth.loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('获取验证码'),
        ),
      );
    }

    if (_step == 1) {
      final captchaValid = _captchaCtrl.text.length >= 4;
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: captchaValid && !auth.loading && !_sendingSms
              ? () async {
                  setState(() => _sendingSms = true);
                  final ok = await auth.sendSmsCode(_phoneCtrl.text, _captchaCtrl.text);
                  if (ok && mounted) setState(() => _step = 2);
                  if (mounted) setState(() => _sendingSms = false);
                }
              : null,
          child: _sendingSms || auth.loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('发送短信验证码'),
        ),
      );
    }

    // step == 2
    final smsValid = _smsCtrl.text.length >= 4;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: smsValid && !auth.loading
            ? () async {
                final ok = await auth.login(_phoneCtrl.text, _smsCtrl.text);
                if (ok && mounted) {
                  await DisclaimerDialog.showIfNeeded(context);
                  if (mounted) Navigator.of(context).pushReplacementNamed('/main');
                }
              }
            : null,
        child: auth.loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('登录'),
      ),
    );
  }
}
