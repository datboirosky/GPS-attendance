//ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'dart:convert';
import 'api_server.dart'; // ApiService
import 'student_dashboard.dart';
import 'lecturer_dashboard.dart';
import 'admin_dashboard.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For .env support
import 'package:local_auth/local_auth.dart'; // Import local_auth
import 'package:local_auth_android/local_auth_android.dart'; // For Android-specific options
//import 'package:local_auth_windows/local_auth_windows.dart';
//import 'package:local_auth_ios/local_auth_ios.dart'; // For iOS-specific options

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load .env file
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Student Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromARGB(255, 178, 179, 180).withOpacity(0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/student_dashboard': (context) => StudentDashboard(
          userData:
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>,
        ),
        '/lecturer_dashboard': (context) => LecturerDashboard(
          userData:
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>,
        ),
        '/admin_dashboard': (context) => AdminDashboard(
          userData:
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>,
        ),
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _LoginPageState();
}

class _LoginPageState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = "student";
  bool isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Biometric authentication variables
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isBiometricEnabledForUser = false;
  String? _storedEmailForBiometrics;
  String? _storedPasswordForBiometrics;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _checkBiometricsAvailability();
    _loadBiometricSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- Biometric Methods ---
  Future<void> _checkBiometricsAvailability() async {
    bool canCheckBiometrics = false;
    try {
      canCheckBiometrics = await _localAuth.canCheckBiometrics;
    } catch (e) {
      print("Error checking biometrics: $e");
    }
    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });
  }

  Future<void> _loadBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final storedEmail = prefs.getString('biometric_email');
    final storedPassword = prefs.getString('biometric_password');

    if (!mounted) return;
    setState(() {
      _isBiometricEnabledForUser = biometricEnabled;
      _storedEmailForBiometrics = storedEmail;
      _storedPasswordForBiometrics = storedPassword;
    });

    // If biometrics are enabled and credentials are stored, try to authenticate
    if (_isBiometricEnabledForUser &&
        _canCheckBiometrics &&
        storedEmail != null &&
        storedPassword != null) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() => isLoading = true);
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to log in to CampusTrack',
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric authentication required!',
            cancelButton: 'No thanks',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print("Error during biometric authentication: $e");
      _showMessage(
        "Biometric authentication failed. Please try again or use email/password.",
      );
    } finally {
      setState(() => isLoading = false);
    }

    if (authenticated) {
      if (_storedEmailForBiometrics != null &&
          _storedPasswordForBiometrics != null) {
        // Use the stored credentials to perform the actual login
        emailController.text = _storedEmailForBiometrics!;
        passwordController.text = _storedPasswordForBiometrics!;
        await loginUser(isBiometricLogin: true);
      } else {
        _showMessage(
          "Biometric credentials not found. Please log in with email/password.",
        );
      }
    } else {
      _showMessage("Biometric authentication failed.");
    }
  }

  Future<void> _saveBiometricSettings(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', true);
    await prefs.setString('biometric_email', email);
    await prefs.setString('biometric_password', password);
    setState(() {
      _isBiometricEnabledForUser = true;
      _storedEmailForBiometrics = email;
      _storedPasswordForBiometrics = password;
    });
  }

  Future<void> _disableBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', false);
    await prefs.remove('biometric_email');
    await prefs.remove('biometric_password');
    setState(() {
      _isBiometricEnabledForUser = false;
      _storedEmailForBiometrics = null;
      _storedPasswordForBiometrics = null;
    });
    _showMessage("Biometric login disabled.");
  }

  // --- Login User Method ---
  Future<void> loginUser({bool isBiometricLogin = false}) async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      print("Raw Response: '${jsonEncode(response)}'");

      if (response['status'] == 'success') {
        final user = response['user'];

        String role = (user['user_type'] ?? "student").toLowerCase();

        // Prompt user to enable biometrics if not already enabled and it's a successful password login
        if (!isBiometricLogin &&
            _canCheckBiometrics &&
            !_isBiometricEnabledForUser) {
          _showBiometricSetupDialog(
            emailController.text.trim(),
            passwordController.text.trim(),
          );
        }

        // Navigation
        if (role == "student") {
          Navigator.pushReplacementNamed(
            context,
            '/student_dashboard',
            arguments: user,
          );
        } else if (role == "lecturer") {
          Navigator.pushReplacementNamed(
            context,
            '/lecturer_dashboard',
            arguments: user,
          );
        } else if (role == "admin") {
          Navigator.pushReplacementNamed(
            context,
            '/admin_dashboard',
            arguments: user,
          );
        } else {
          _showMessage("Unknown role: $role");
        }
      } else {
        _showMessage(response['message'] ?? "Login failed");
      }
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showBiometricSetupDialog(String email, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text(
          'Would you like to enable fingerprint/Face ID for faster logins?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('No Thanks'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _saveBiometricSettings(email, password);
              _showMessage("Biometric login enabled!");
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade700, Colors.indigo.shade900],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(opacity: _fadeAnimation.value, child: child),
            );
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Title with animation
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.place, size: 70, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          "CampusTrack",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Smart Attendance System",
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: const Icon(
                              Icons.email,
                              color: Colors.white70,
                            ),
                            labelStyle: const TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.white70,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            labelStyle: const TextStyle(color: Colors.white70),
                          ),
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () =>
                                      loginUser(), // Call loginUser without biometric flag
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        if (_canCheckBiometrics &&
                            _isBiometricEnabledForUser) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : _authenticateWithBiometrics,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.fingerprint),
                              label: const Text(
                                "Login with Biometrics",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _disableBiometricSettings,
                            child: const Text(
                              "Disable Biometric Login",
                              style: TextStyle(
                                color: Colors.white70,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Register link with animation
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.6, 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.rightToLeftWithFade,
                                child: const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Register",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  String fullname = '';
  String email = '';
  String userpassword = '';
  String userType = 'student';
  String studentId = '';
  String department = '';
  String year = '';
  bool isLoading = false;
  bool _obscurePassword = true;

  // Department options - you can customize this list
  final List<String> departments = [
    'Administration',
    'Management Studies',
    'Finance Studies',
    'Education Humanities',
    'Education Science',
    'Social Sciences',
    'Theology',
    'Computer Science',
  ];

  // Year options
  final List<String> years = [
    'All Years',
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Biometric variables
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  bool _biometricsOptedIn = false; // User toggle for opt-in
  bool _biometricsTested = false; // True if test scan succeeded

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _checkBiometricsAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Enhanced: Check biometrics availability and enrolled types
  Future<void> _checkBiometricsAvailability() async {
    bool canCheck = false;
    List<BiometricType> available = [];
    try {
      canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck) {
        available = await _localAuth.getAvailableBiometrics();
      }
    } catch (e) {
      print("Error checking biometrics: $e");
    }
    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canCheck;
      _availableBiometrics = available;
    });
  }

  // NEW: Test and enable biometrics (called from UI button)
  Future<void> _testAndEnableBiometrics() async {
    if (_availableBiometrics.isEmpty) {
      await _showEnrollmentGuideDialog();
      return;
    }

    String biometricType =
        _availableBiometrics.contains(BiometricType.fingerprint)
        ? 'fingerprint'
        : 'Face ID';

    setState(() => isLoading = true);
    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your $biometricType to enable secure login',
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric registration',
            cancelButton: 'No thanks',
          ),
        ],
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print("Biometric test error: $e");
    } finally {
      setState(() => isLoading = false);
    }

    if (authenticated && mounted) {
      setState(() {
        _biometricsTested = true;
      });
      _showMessage(
        "Biometric setup successful! Your $biometricType is linked for future logins.",
        isError: false,
      );
    } else {
      setState(() {
        _biometricsOptedIn = false; // Reset toggle on failure
        _biometricsTested = false;
      });
      _showMessage(
        "Biometric scan failed. Please try again or skip.",
        isError: true,
      );
    }
  }

  // NEW: Show guide dialog if no biometrics enrolled
  Future<void> _showEnrollmentGuideDialog() async {
    final bool? goToSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enroll Biometrics on Your Device'),
        content: const Text(
          'To enable fingerprint or Face ID, first set it up in your device settings. '
          'This is secure and private—your data never leaves your phone.\n\n'
          '• Android: Settings > Security > Fingerprint (or Face Unlock)\n'
          '• iOS: Settings > Face ID & Passcode (or Touch ID & Passcode)\n\n'
          'After enrolling, toggle this option and test again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Got It'),
          ),
        ],
      ),
    );

    if (goToSettings == true) {
      // Optional: Use url_launcher to open settings (add dependency if needed)
      // launchUrl(Uri.parse(Platform.isAndroid ? 'android.settings.SECURITY_SETTINGS' : 'App-Prefs:root=General&path=PASSCODE'));
      _showMessage(
        "Please enroll biometrics in settings, then return to test.",
      );
    }
  }

  // UPDATED: _register method
  Future<void> _register() async {
    setState(() => isLoading = true);
    try {
      final Map<String, String> data = {
        'fullname': fullname,
        'email': email,
        'password': userpassword,
        'user_type': userType,
        'department': department,
      };

      if (userType == 'student') {
        data['student_id'] = studentId;
        data['year'] = year;
      } else if (userType == 'lecturer') {
        data['lecturer_number'] = studentId;
      } else if (userType == 'admin') {
        data['admin_number'] = studentId;
      }

      print('Registering with: $data');

      final response = await apiService.register(data);

      print('Registration response: $response');

      final bool isSuccess = response['status'] == 'success';
      _showMessage(response['message'] ?? 'Unknown error', isError: !isSuccess);

      if (isSuccess) {
        if (mounted) {
          Navigator.pop(context); // Back to login
        }
      }
    } catch (e) {
      _showMessage("Error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Enhanced: Helper for messages
  void _showMessage(String msg, {bool isError = false, int durationMs = 4000}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(milliseconds: durationMs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? biometricType;
    if (_availableBiometrics.isNotEmpty) {
      biometricType = _availableBiometrics.contains(BiometricType.fingerprint)
          ? 'Fingerprint'
          : 'Face ID';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade800, Colors.blue.shade700],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(opacity: _fadeAnimation.value, child: child),
            );
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Register Title
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Join our smart attendance system",
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),

                  const SizedBox(height: 40),

                  // Registration Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // ... (All existing TextFields and Dropdowns remain exactly the same)
                        TextField(
                          onChanged: (value) => fullname = value,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(
                              Icons.person,
                              color: Colors.white70,
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => email = value,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(
                              Icons.email,
                              color: Colors.white70,
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => userpassword = value,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.white70,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            labelStyle: const TextStyle(color: Colors.white70),
                          ),
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => studentId = value,
                          decoration: const InputDecoration(
                            labelText: 'User  ID',
                            prefixIcon: Icon(
                              Icons.badge,
                              color: Colors.white70,
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: userType,
                          dropdownColor: Colors.indigo[800],
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          decoration: const InputDecoration(
                            labelText: "User  Type",
                            prefixIcon: Icon(
                              Icons.people,
                              color: Colors.white70,
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: <String>['student', 'lecturer', 'admin']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value[0].toUpperCase() + value.substring(1),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (String? newValue) =>
                              setState(() => userType = newValue!),
                        ),
                        const SizedBox(height: 16),
                        // Department dropdown
                        DropdownButtonFormField<String>(
                          initialValue: department.isNotEmpty
                              ? department
                              : null,
                          dropdownColor: Colors.indigo[800],
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Department",
                            prefixIcon: Icon(
                              Icons.school,
                              color: Colors.white70,
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: departments
                              .map(
                                (dept) => DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept),
                                ),
                              )
                              .toList(),
                          onChanged: (String? newValue) =>
                              setState(() => department = newValue!),
                        ),
                        const SizedBox(height: 16),

                        // Year dropdown
                        DropdownButtonFormField<String>(
                          initialValue: year.isNotEmpty ? year : null,
                          dropdownColor: Colors.indigo[800],
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Year",
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: years
                              .map(
                                (yr) => DropdownMenuItem(
                                  value: yr,
                                  child: Text(yr),
                                ),
                              )
                              .toList(),
                          onChanged: (String? newValue) =>
                              setState(() => year = newValue!),
                        ),
                        const SizedBox(height: 16),

                        // NEW: Biometric Setup UI Section (only if biometrics supported)
                        if (_canCheckBiometrics) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _availableBiometrics.contains(
                                            BiometricType.fingerprint,
                                          )
                                          ? Icons.fingerprint
                                          : Icons.face,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Enable ${biometricType ?? 'Biometric'} Login',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _biometricsOptedIn,
                                      onChanged: (value) {
                                        setState(() {
                                          _biometricsOptedIn = value;
                                          if (!value) {
                                            _biometricsTested =
                                                false; // Reset on toggle off
                                          }
                                        });
                                        if (value) {
                                          _testAndEnableBiometrics();
                                        }
                                      },
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: Colors.white70,
                                      inactiveThumbColor: Colors.white54,
                                      inactiveTrackColor: Colors.white24,
                                    ),
                                  ],
                                ),
                                if (_biometricsOptedIn) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Use your ${biometricType ?? 'biometrics'} for quick, secure access. '
                                    'Your data stays safely on your device—no information is stored on our server.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_biometricsTested)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Biometrics verified and ready!',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_biometricsOptedIn &&
                                          _biometricsTested) ...[
                                        const Icon(Icons.security, size: 18),
                                        const SizedBox(width: 8),
                                      ],
                                      const Text(
                                        "Register",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
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
