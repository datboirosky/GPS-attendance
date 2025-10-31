// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_server.dart';
import 'package:shimmer/shimmer.dart';
import 'package:permission_handler/permission_handler.dart';

class LecturerDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const LecturerDashboard({super.key, required this.userData});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard>
    with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  bool _isAttendanceOpen = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceList = [];
  double _attendancePercentage = 0.0;
  int _presentCount = 0;
  int _totalStudents = 0;

  Map<String, dynamic> _fetchedCurrentCourse = {};
  final ApiService _apiService = ApiService();

  // New state variables
  List<Map<String, dynamic>> _lecturerCourses = [];
  Map<String, dynamic> _selectedCourse = {};

  // Profile settings state
  bool _showProfileSettings = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _classController = TextEditingController();
  String _selectedClass = '';

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();

    _initializeDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeDashboardData() async {
    setState(() => _isLoading = true);
    await Future.wait([_getCurrentLocation(), _fetchLecturerCourses()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchLecturerCourses() async {
    final token = await getLecturerToken();
    if (token == null) return;

    final result = await _apiService.fetchLecturerCourses(
      widget.userData['lecturer_id'].toString(),
      token,
    );
    if (result['success']) {
      setState(() {
        _lecturerCourses = List<Map<String, dynamic>>.from(result['courses']);
        if (_lecturerCourses.isNotEmpty) {
          _selectedCourse = _lecturerCourses[0];
          _fetchedCurrentCourse = _selectedCourse;
          _loadClassData();
        } else {
          _fetchedCurrentCourse = {
            'course_code': 'N/A',
            'course_name': 'No Course Assigned',
            'class_id': 'N/A',
          };
          _attendanceList = [];
          _totalStudents = 0;
        }
      });
    }
  }

  Future<void> _loadClassData() async {
    final token = await getLecturerToken();
    if (token == null) return;

    final result = await _apiService.fetchCourseStudentsForLecturer(
      _selectedCourse['course_code'],
      widget.userData['department'],
      token,
    );
    if (result['success']) {
      setState(() {
        _attendanceList = List<Map<String, dynamic>>.from(result['students'])
            .map(
              (student) => {
                'user_id': student['user_id'],
                'name': student['full_name'],
                'student_number': student['student_number'],
                'status': 'pending',
                'timestamp': null,
              },
            )
            .toList();
        _totalStudents = _attendanceList.length;
        _updateAttendanceStats();
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isDenied || status.isRestricted) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Location permission is permanently denied. Please enable it from app settings to track your location for student attendance.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
      }
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });

      // Update lecturer's location in the database
      await _updateLecturerLocation(position);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  Future<void> _updateLecturerLocation(Position position) async {
    final token = await getLecturerToken();
    if (token == null) return;

    await _apiService.updateLecturerLocation(
      widget.userData['lecturer_id'].toString(),
      widget.userData['department'],
      position.latitude,
      position.longitude,
      token,
    );
  }

  Future<void> _toggleAttendance() async {
    if (_selectedCourse.isEmpty || _selectedCourse['course_code'] == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a class first.')),
      );
      return;
    }

    await _getCurrentLocation();

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine your location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final token = await getLecturerToken();
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (!_isAttendanceOpen) {
      // Open attendance
      final result = await _apiService.openAttendanceSession(
        _selectedCourse['course_code'],
        widget.userData['lecturer_id'].toString(),
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        token,
      );
      if (result['success']) {
        setState(() {
          _isAttendanceOpen = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Attendance is now open')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open attendance: ${result['message']}'),
          ),
        );
      }
    } else {
      // Close attendance
      final result = await _apiService.closeAttendanceSession(
        _selectedCourse['course_code'],
        widget.userData['lecturer_id'].toString(),
        token,
      );
      if (result['success']) {
        setState(() {
          _isAttendanceOpen = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance is now closed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close attendance: ${result['message']}'),
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _markStudentPresent(String userId) async {
    if (!_isAttendanceOpen) return;

    final token = await getLecturerToken();
    if (token == null) return;

    final result = await _apiService.markAttendance(
      userId,
      _selectedCourse['course_code']!,
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    if (result['success']) {
      setState(() {
        _attendanceList = _attendanceList.map((student) {
          if (student['user_id'].toString() == userId) {
            return {
              ...student,
              'status': 'present',
              'timestamp': DateTime.now(),
            };
          }
          return student;
        }).toList();
        _updateAttendanceStats();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark student present: ${result['message']}'),
        ),
      );
    }
  }

  void _updateAttendanceStats() {
    _presentCount = _attendanceList
        .where((student) => student['status'] == 'present')
        .length;
    _attendancePercentage = _totalStudents > 0
        ? _presentCount / _totalStudents
        : 0.0;
  }

  Future<void> _generateAttendancePDF() async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfGrid grid = PdfGrid();

    // Add columns
    grid.columns.add(count: 4);
    final PdfGridRow headerRow = grid.headers.add(1)[0];
    headerRow.cells[0].value = 'Student Number';
    headerRow.cells[1].value = 'Name';
    headerRow.cells[2].value = 'Status';
    headerRow.cells[3].value = 'Time';

    // Add rows
    for (var student in _attendanceList) {
      final PdfGridRow row = grid.rows.add();
      row.cells[0].value = student['student_number']?.toString() ?? '';
      row.cells[1].value = student['name'] ?? '';
      row.cells[2].value = student['status'] ?? '';
      row.cells[3].value = student['timestamp'] != null
          ? DateFormat('HH:mm').format(student['timestamp'])
          : 'N/A';
    }

    // Draw grid
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 50, page.getClientSize().width, 0),
    );

    // Add header
    page.graphics.drawString(
      '${_fetchedCurrentCourse['course_code'] ?? ''} - ${_fetchedCurrentCourse['course_name'] ?? ''}',
      font,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
    );
    page.graphics.drawString(
      'Attendance Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      PdfStandardFont(PdfFontFamily.helvetica, 10),
      bounds: Rect.fromLTWH(0, 20, page.getClientSize().width, 30),
    );

    // Save document
    final Directory directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/attendance_report.pdf';
    final File file = File(path);
    await file.writeAsBytes(await document.save());

    document.dispose();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PDF saved to $path')));
  }

  Future<void> _createSchedule() async {
    final token = await getLecturerToken();
    if (token == null) return;

    // For simplicity, we'll just show a dialog to get the schedule details.
    // In a real app, you would use a form.
    final scheduleDetails = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final dateController = TextEditingController();
        final timeController = TextEditingController();
        final notesController = TextEditingController();

        return AlertDialog(
          title: const Text('Create Schedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    dateController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(pickedDate);
                  }
                },
              ),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Time (HH:MM)'),
                onTap: () async {
                  TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime != null) {
                    timeController.text = pickedTime.format(context);
                  }
                },
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (e.g., Room)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'schedule_date': dateController.text,
                  'schedule_time': timeController.text,
                  'notes': notesController.text,
                });
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (scheduleDetails != null) {
      final courseCode = _selectedCourse['course_code'];
      final lecturerId = widget.userData['lecturer_id']?.toString();
      final scheduleDate = scheduleDetails['schedule_date'];
      final scheduleTime = scheduleDetails['schedule_time'];
      final notes = scheduleDetails['notes'];

      if (courseCode == null || courseCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No course selected or course code is invalid.')),
        );
        return;
      }

      if (lecturerId == null || lecturerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lecturer ID is missing.')),
        );
        return;
      }
      
      if (scheduleDate == null || scheduleDate.isEmpty || scheduleTime == null || scheduleTime.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid date and time.')),
        );
        return;
      }

      final result = await _apiService.createSchedule(
        courseCode,
        lecturerId,
        scheduleDate,
        scheduleTime,
        notes ?? '', // Send empty string for notes if null
        token,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule created successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create schedule: ${result['message']}'),
          ),
        );
      }
    }
  }

  Future<void> _assignClassToLecturer() async {
    final token = await getLecturerToken();
    if (token == null) return;

    final result = await _apiService.assignClassToLecturer(
      widget.userData['lecturer_id'].toString(),
      _selectedClass,
      token,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class assigned successfully')),
      );
      _classController.clear();
      _fetchLecturerCourses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign class: ${result['message']}')),
      );
    }
  }

  Future<String?> getLecturerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lecturer_token');
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('lecturer_token');
    await prefs.remove('lecturer_user');

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileInfoItem(
                        'Name',
                        widget.userData['full_name'] ?? 'Not available',
                        Icons.person,
                      ),
                      const Divider(),
                      _buildProfileInfoItem(
                        'Email',
                        widget.userData['email'] ?? 'Not available',
                        Icons.email,
                      ),
                      const Divider(),
                      _buildProfileInfoItem(
                        'Department',
                        widget.userData['department'] ?? 'Not available',
                        Icons.business,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Assign Class',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _classController,
                          decoration: const InputDecoration(
                            labelText: 'Enter Class Code or Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.class_),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a class';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.assignment),
                            label: const Text('Assign Class'),
                            onPressed: _assignClassToLecturer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Course Card
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Course',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fetchedCurrentCourse['course_name'] ?? 'No course',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${_fetchedCurrentCourse['course_code'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _currentPosition != null
                                  ? 'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                  : 'Location: Not available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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

          const SizedBox(height: 20),

          // Attendance Control Button
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ElevatedButton.icon(
                  icon: Icon(_isAttendanceOpen ? Icons.lock : Icons.lock_open),
                  label: Text(
                    _isAttendanceOpen ? 'Close Attendance' : 'Open Attendance',
                  ),
                  onPressed: _toggleAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAttendanceOpen
                        ? Colors.red
                        : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Attendance Stats
          if (_isAttendanceOpen)
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Present',
                          _presentCount.toString(),
                          Colors.green,
                        ),
                        _buildStatItem(
                          'Total',
                          _totalStudents.toString(),
                          Colors.blue,
                        ),
                        _buildStatItem(
                          'Percentage',
                          '${(_attendancePercentage * 100).toStringAsFixed(1)}%',
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Student List
          Expanded(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Students',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _attendanceList.length,
                            itemBuilder: (context, index) {
                              final student = _attendanceList[index];
                              return _buildStudentListItem(student, index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generate PDF'),
                    onPressed: _generateAttendancePDF,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Create Schedule'),
                    onPressed: _createSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentListItem(Map<String, dynamic> student, int index) {
    Color statusColor;
    IconData statusIcon;

    switch (student['status']) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            (index + 1).toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        title: Text(student['name'] ?? ''),
        subtitle: Text('ID: ${student['student_number'] ?? ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor),
            if (student['timestamp'] != null) ...[
              const SizedBox(width: 8),
              Text(
                DateFormat('HH:mm').format(student['timestamp']),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        onTap: () => _markStudentPresent(student['user_id'].toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              setState(() {
                _showProfileSettings = !_showProfileSettings;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoader()
          : _showProfileSettings
          ? _buildProfileSettings()
          : _buildDashboardContent(),
    );
  }
}