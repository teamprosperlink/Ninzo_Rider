import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_session.dart';
import 'home_router.dart';

/// Phone + OTP login. OTP is mocked as 1234 until an SMS provider
/// (e.g. Firebase Auth) is integrated.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _demoOtp = '1234';

  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim())) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _otpSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo OTP: $_demoOtp')));
  }

  Future<void> _verifyOtp() async {
    if (_otp.text.trim() != _demoOtp) {
      setState(() => _error = 'Incorrect OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await AppSession.login(_phone.text.trim());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => homeScreenFor(AppSession.mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Icon(Icons.two_wheeler, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'NinzoRider',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Ride or drive — one account', textAlign: TextAlign.center),
            const SizedBox(height: 48),
            Text(
              _otpSent ? 'Enter OTP' : 'Enter your mobile number',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_otpSent ? 'OTP sent to +91 ${_phone.text}' : "We'll send you a verification code"),
            const SizedBox(height: 24),
            if (!_otpSent)
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(prefixText: '+91 ', labelText: 'Mobile number', errorText: _error),
              )
            else
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: '4-digit OTP', errorText: _error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_otpSent ? 'Verify & Continue' : 'Send OTP'),
            ),
            if (_otpSent)
              TextButton(
                onPressed: () => setState(() {
                  _otpSent = false;
                  _otp.clear();
                  _error = null;
                }),
                child: const Text('Change number'),
              ),
          ],
        ),
      ),
    );
  }
}
