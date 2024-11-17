import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_messaging_service.dart';
import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_page.dart';

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _captchaController;
  String _captchaSvg = '';
  int _captchaAnswer = 0;
  bool _isLoading = false;
  bool _acceptTerms = false;
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _captchaController = TextEditingController();
    _generateCaptcha();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    final random = Random();
    final operations = ['+', '-', '*'];
    final operation = operations[random.nextInt(operations.length)];
    int a, b;

    switch (operation) {
      case '+':
        a = random.nextInt(50) + 1;
        b = random.nextInt(50) + 1;
        _captchaAnswer = a + b;
        break;
      case '-':
        a = random.nextInt(50) + 51; // Ensure a > b
        b = random.nextInt(50) + 1;
        _captchaAnswer = a - b;
        break;
      case '*':
        a = random.nextInt(12) + 1;
        b = random.nextInt(12) + 1;
        _captchaAnswer = a * b;
        break;
      default:
        throw Exception('Invalid operation');
    }

    final captchaText = '$a $operation $b = ?';

    // Generate SVG for CAPTCHA
    final width = 200;
    final height = 80;
    final fontSize = 24;
    final charSpacing = width / (captchaText.length + 1);

    String svgContent = '''
  <svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">
    <rect width="$width" height="$height" fill="#f0f0f0"/>
  ''';

    for (int i = 0; i < captchaText.length; i++) {
      final x = charSpacing * (i + 1);
      final y = height / 2 + random.nextDouble() * 20 - 10;
      final rotate = random.nextDouble() * 40 - 20;
      final char = captchaText[i];

      svgContent += '''
    <text x="$x" y="$y" font-family="Arial" font-size="$fontSize" fill="#333333" transform="rotate($rotate, $x, $y)">
      $char
    </text>
    ''';
    }

    // Add some random lines to make it harder for bots
    for (int i = 0; i < 5; i++) {
      final x1 = random.nextDouble() * width;
      final y1 = random.nextDouble() * height;
      final x2 = random.nextDouble() * width;
      final y2 = random.nextDouble() * height;
      svgContent += '''
    <line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="#666666" stroke-width="1"/>
    ''';
    }

    svgContent += '</svg>';
    _captchaSvg = svgContent;

    setState(() {});
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_acceptTerms) {
      if (!_acceptTerms) {
        _showErrorSnackBar(
            'Please accept the terms and conditions to register.');
      }
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      String? fcmToken = await _messagingService.getToken();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(
            FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid),
            {
              'nickname': _nicknameController.text.trim(),
              'email': _emailController.text.trim(),
              'fcmToken': fcmToken,
            });
      });

      _showSuccessSnackBar('Registration successful.');

      // Navigate to main page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainPage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getErrorMessage(e.code);
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/registration_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Nickname',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a nickname';
                      }
                      if (value.length < 3) {
                        return 'Nickname must be at least 3 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$')
                          .hasMatch(value)) {
                        return 'Password must contain at least one letter and one number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 80,
                    child: SvgPicture.string(_captchaSvg),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _captchaController,
                    decoration: const InputDecoration(
                      labelText: 'Enter the result of the equation',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the CAPTCHA result';
                      }
                      if (int.tryParse(value) != _captchaAnswer) {
                        return 'Incorrect CAPTCHA result';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _generateCaptcha,
                    child: Text('Refresh CAPTCHA'),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: const Text(
                          'Terms and Conditions for Scheduler App\n'
                          '\n'
                          '1. Acceptance of Terms\n'
                          'By downloading, installing, or using the Scheduler app ("Scheduler"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, do not use the App.\n'
                          '\n'
                          '2. Use of the App\n'
                          '2.1. You must be at least 13 years old to use this App.\n'
                          '2.2. You are responsible for maintaining the confidentiality of your account and password.\n'
                          '2.3. You agree to use the App only for lawful purposes and in accordance with these Terms.\n'
                          '\n'
                          '3. User Content\n'
                          '3.1. You retain ownership of any content you submit to the App.\n'
                          '3.2. By submitting content, you grant the App a worldwide, non-exclusive, royalty-free license to use, reproduce, and distribute that content within the App.\n'
                          '\n'
                          '4. Intellectual Property\n'
                          '4.1. The App, including its code, design, and content, is protected by copyright and other intellectual property laws.\n'
                          '4.2. All rights, title, and interest in and to the App are and will remain the exclusive property of the developer.\n'
                          '\n'
                          '5. Privacy and Data Protection\n'
                          '5.1. Our processing of personal data is governed by our Privacy Policy and complies with the General Data Protection Regulation (GDPR).\n'
                          '5.2. By using the App, you consent to the collection and use of your information as described in our Privacy Policy.\n'
                          '5.3. We process personal data on the following legal bases as per GDPR Article 6:\n'
                          '     a) Consent (for optional features)\n'
                          '     b) Contractual necessity (to provide our service)\n'
                          '     c) Legal obligation\n'
                          '     d) Legitimate interests (to improve our service)\n'
                          '5.4. We retain personal data only for as long as necessary to provide our service or comply with legal obligations.\n'
                          '\n'
                          '6. User Rights under GDPR\n'
                          '6.1. Right to access: You can request a copy of your personal data.\n'
                          '6.2. Right to rectification: You can request correction of inaccurate personal data.\n'
                          '6.3. Right to erasure: You can request deletion of your personal data in certain circumstances.\n'
                          '6.4. Right to restrict processing: You can request restriction of processing of your personal data.\n'
                          '6.5. Right to data portability: You can request a copy of your data in a machine-readable format.\n'
                          '6.6. Right to object: You can object to processing of your personal data in certain circumstances.\n'
                          '6.7. Rights related to automated decision-making: You have rights related to any automated decision-making or profiling.\n'
                          '\n'
                          '7. Data Transfers\n'
                          '7.1. We may transfer your data to countries outside the EEA. In such cases, we ensure appropriate safeguards are in place, such as Standard Contractual Clauses.\n'
                          '\n'
                          '8. Account Inactivity and Deletion\n'
                          '8.1. If your account remains inactive (no login) for a period of 12 months or more, we reserve the right to automatically delete your account and all associated data without prior warning.\n'
                          '8.2. This deletion is permanent and cannot be undone. It is your responsibility to log in periodically if you wish to maintain your account.\n'
                          '\n'
                          '9. Disclaimer of Warranties\n'
                          '9.1. The App is provided "as is" without any warranties, express or implied.\n'
                          '9.2. We do not warrant that the App will be error-free or uninterrupted.\n'
                          '\n'
                          '10. Limitation of Liability\n'
                          '10.1. To the fullest extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the App.\n'
                          '\n'
                          '11. Changes to the Terms\n'
                          'We reserve the right to modify these Terms at any time. We will notify users of any significant changes.\n'
                          '\n'
                          '12. Termination\n'
                          'We may terminate or suspend your access to the App immediately, without prior notice or liability, for any reason.\n'
                          '\n'
                          '13. Governing Law and Dispute Resolution\n'
                          '13.1. These Terms shall be governed by and construed in accordance with the laws of Poland, without regard to its conflict of law provisions.\n'
                          '13.2. Any disputes arising from these Terms or your use of the App shall be subject to the exclusive jurisdiction of the courts of Poland.\n'
                          '13.3. For EU consumers, this does not affect your rights under mandatory local consumer protection laws.\n'
                          '\n'
                          '14. GDPR Compliance\n'
                          '14.1. For users in the European Economic Area (EEA), we comply with the GDPR.\n'
                          '14.2. You have the right to access, rectify, or erase your personal data, as well as the right to restrict or object to processing and the right to data portability.\n'
                          '14.3. You may withdraw your consent at any time, without affecting the lawfulness of processing based on consent before its withdrawal.\n'
                          '14.4. You have the right to lodge a complaint with a supervisory authority.\n'
                          '14.5. Our Data Protection Officer can be contacted at aidruidvisions@gmail.com.\n'
                          '\n'
                          '15. Beta Version and Data Reset\n'
                          '15.1. The current state of the application is still in the testing phase.\n'
                          '15.2. The developer reserves the right to completely clear the application\'s database in case of renovation, including accounts, photos, and all related data without warning.\n'
                          '15.3. By using this application, you acknowledge and accept that your data may be deleted at any time during this testing phase.\n'
                          '15.4. It is recommended to keep important information stored elsewhere and not solely rely on this application for critical data storage during this period.\n'
                          '\n'
                          '16. Copyright Notice\n'
                          '© 2024 Paweł Dyjan. All rights reserved. The Scheduler app, including its code, design, and content, is the property of Paweł Dyjan and is protected by copyright laws and international treaty provisions.\n'
                          '\n'
                          '17. Contact Information\n'
                          'For any questions about these Terms, please contact us at aidruidvisions@gmail.com.\n'
                          '\n'
                          'By using the Scheduler app, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.\n'),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) {
                          setState(() {
                            _acceptTerms = value!;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'I accept the Terms and Conditions',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
