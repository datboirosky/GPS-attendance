import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart'; // AuthScreen for logout
import 'api_server.dart'; // For API calls
import 'package:shared_preferences/shared_preferences.dart'; // For clearing token on logout

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AdminDashboard({super.key, required this.userData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _attendanceReports = [];
  final ApiService _apiService = ApiService(); // API service instance
  String _searchQuery = ''; // For search filtering

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final usersResponse = await _apiService.fetchAllUsers();
      final coursesResponse = await _apiService.fetchAllCourses();
      final reportsResponse = await _apiService.fetchAttendanceReports();

      if (!mounted) return;

      setState(() {
        if (usersResponse['success'] == true) {
          _users = List<Map<String, dynamic>>.from(usersResponse['users']);
        } else {
          _showMessage(usersResponse['message'] ?? 'Failed to load users', isError: true);
        }

        if (coursesResponse['success'] == true) {
          _courses = List<Map<String, dynamic>>.from(coursesResponse['courses']);
        } else {
          _showMessage(coursesResponse['message'] ?? 'Failed to load courses', isError: true);
        }

        if (reportsResponse['success'] == true) {
          _attendanceReports = List<Map<String, dynamic>>.from(reportsResponse['reports']);
        } else {
          _showMessage(reportsResponse['message'] ?? 'Failed to load reports', isError: true);
        }
      });
    } catch (e) {
      if (mounted) {
        _showMessage('An error occurred: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- User Management Actions ---
  Future<void> _resetUserPassword(String userId) async {
    setState(() => _isLoading = true);
    final response = await _apiService.resetUserPassword(userId);
    if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Password reset initiated',
        isError: !response['success'],
      );
    }
  }

  Future<void> _toggleUserStatus(String userId, String currentStatus) async {
    setState(() => _isLoading = true);
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final response = await _apiService.updateUserStatus(userId, newStatus);
    if (response['success'] && mounted) {
      setState(() {
        _users = _users.map((user) {
          if (user['id'].toString() == userId) {
            return {...user, 'status': newStatus};
          }
          return user;
        }).toList();
        _isLoading = false;
      });
      _showMessage('User status updated to $newStatus');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Failed to update status',
        isError: true,
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final response = await _apiService.deleteUser(userId);
    if (response['success'] && mounted) {
      setState(() {
        _users.removeWhere((user) => user['id'].toString() == userId);
        _isLoading = false;
      });
      _showMessage('User deleted successfully');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Failed to delete user',
        isError: true,
      );
    }
  }

  // --- Course Management Actions ---
  Future<void> _addCourse(Map<String, dynamic> newCourse) async {
    setState(() => _isLoading = true);
    final response = await _apiService.addCourse(newCourse);
    if (response['success'] && mounted) {
      await _loadInitialData();
      _showMessage('Course added successfully');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Failed to add course',
        isError: true,
      );
    }
  }

  Future<void> _updateCourse(
    String courseId,
    Map<String, dynamic> updatedCourse,
  ) async {
    setState(() => _isLoading = true);
    final response = await _apiService.updateCourse(courseId, updatedCourse);
    if (response['success'] && mounted) {
      await _loadInitialData();
      _showMessage('Course updated successfully');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Failed to update course',
        isError: true,
      );
    }
  }

  Future<void> _toggleCourseStatus(
    String courseId,
    String currentStatus,
  ) async {
    setState(() => _isLoading = true);
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final updatedData = {'status': newStatus};
    final response = await _apiService.updateCourse(courseId, updatedData);
    if (response['success'] && mounted) {
      setState(() {
        _courses = _courses.map((course) {
          if (course['course_id'].toString() == courseId) {
            return {...course, 'status': newStatus};
          }
          return course;
        }).toList();
        _isLoading = false;
      });
      _showMessage('Course status updated to $newStatus');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Failed to update status',
        isError: true,
      );
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text(
          'Are you sure? This may affect attendance records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final response = await _apiService.deleteCourse(courseId);
    if (response['success'] && mounted) {
      setState(() {
        _courses.removeWhere(
          (course) => course['course_id'].toString() == courseId,
        );
        _isLoading = false;
      });
      _showMessage('Course deleted successfully');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(
        response['message'] ?? 'Failed to delete course',
        isError: true,
      );
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> userData) async {
    setState(() => _isLoading = true);
    final response = await _apiService.updateUser(userId, userData);
    if (response['success'] && mounted) {
      await _loadInitialData();
      _showMessage('User updated successfully');
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showMessage(response['message'] ?? 'Failed to update user', isError: true);
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final fullnameController = TextEditingController(text: user['fullname'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final departmentController = TextEditingController(text: user['department'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullnameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedData = {
                'fullname': fullnameController.text,
                'email': emailController.text,
                'department': departmentController.text,
              };
              await _updateUser(user['id'].toString(), updatedData);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _animationController.forward(from: 0.0); // Re-run animation on tab change
  }

  List<Map<String, dynamic>> _filterUsers(String query) {
    if (query.isEmpty) return _users;
    return _users
        .where(
          (user) =>
              (user['fullname']?.toLowerCase()?.contains(query.toLowerCase()) ?? false) ||
              (user['id']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (user['email']?.toLowerCase()?.contains(query.toLowerCase()) ?? false),
        )
        .toList();
  }

  List<Map<String, dynamic>> _filterCourses(String query) {
    if (query.isEmpty) return _courses;
    return _courses
        .where(
          (course) =>
              (course['course_code']?.toLowerCase()?.contains(query.toLowerCase()) ?? false) ||
              (course['course_name']?.toLowerCase()?.contains(query.toLowerCase()) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filterUsers(_searchQuery);
    final filteredCourses = _filterCourses(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInitialData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF667eea)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 30,
                      color: Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.userData['fullname'] ?? "Admin User",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.userData['user_type'] ?? 'System Administrator',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(0, 'User Management', Icons.people_alt),
            _buildDrawerItem(1, 'Course Management', Icons.school),
            _buildDrawerItem(2, 'Attendance Reports', Icons.assignment),
            _buildDrawerItem(3, 'System Settings', Icons.settings),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildUserManagementTab(filteredUsers),
                        _buildCourseManagementTab(filteredCourses),
                        _buildAttendanceReportsTab(),
                        _buildSystemSettingsTab(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex == index
            ? const Color(0xFF667eea)
            : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: _selectedIndex == index
              ? FontWeight.bold
              : FontWeight.normal,
          color: _selectedIndex == index
              ? const Color(0xFF667eea)
              : Colors.black87,
        ),
      ),
      selected: _selectedIndex == index,
      onTap: () {
        _onItemTapped(index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildUserManagementTab(List<Map<String, dynamic>> users) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search users by name, ID, or email...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF667eea)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final roleSpecificId =
                            user['student_number'] ??
                            user['lecturer_number'] ??
                            user['admin_number'] ??
                            user['id'];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      user['fullname'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF667eea),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        (user['user_type'] ?? 'N/A').toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                      backgroundColor: _getRoleColor(
                                        user['user_type'] ?? '',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $roleSpecificId | Email: ${user['email'] ?? 'N/A'}',
                                ),
                                Text(
                                  'Department: ${user['department'] ?? 'N/A'} | Year: ${user['year'] ?? 'N/A'}',
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Status: ${(user['status'] ?? 'N/A').toUpperCase()}',
                                      style: TextStyle(
                                        color: user['status'] == 'active'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                          onPressed: () => _showEditUserDialog(user),
                                          tooltip: 'Edit User',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.lock_reset,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () => _resetUserPassword(
                                            user['id'].toString(),
                                          ),
                                          tooltip: 'Reset Password',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            user['status'] == 'active'
                                                ? Icons.person_off
                                                : Icons.person_add,
                                            color: user['status'] == 'active'
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                          onPressed: () => _toggleUserStatus(
                                            user['id'].toString(),
                                            user['status'],
                                          ),
                                          tooltip: user['status'] == 'active'
                                              ? 'Deactivate User'
                                              : 'Activate User',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () =>
                                              _deleteUser(user['id'].toString()),
                                          tooltip: 'Delete User',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCourseManagementTab(List<Map<String, dynamic>> courses) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search courses by code or name...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF667eea),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Course',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () => _showAddEditCourseDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : courses.isEmpty
                  ? const Center(child: Text('No courses found'))
                  : ListView.builder(
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        final lecturerName =
                            course['assigned_lecturer_name'] ?? 'Unassigned';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${course['course_code']} - ${course['course_name']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF667eea),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Department: ${course['department']}'),
                                Text('Assigned Lecturer: $lecturerName'),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Status: ${course['status'].toUpperCase()}',
                                      style: TextStyle(
                                        color: course['status'] == 'active'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _showAddEditCourseDialog(
                                            course: course,
                                          ),
                                          tooltip: 'Edit Course',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            course['status'] == 'active'
                                                ? Icons.toggle_on
                                                : Icons.toggle_off,
                                            color: course['status'] == 'active'
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          onPressed: () => _toggleCourseStatus(
                                            course['course_id'].toString(),
                                            course['status'],
                                          ),
                                          tooltip: course['status'] == 'active'
                                              ? 'Deactivate Course'
                                              : 'Activate Course',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () => _deleteCourse(
                                            course['course_id'].toString(),
                                          ),
                                          tooltip: 'Delete Course',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAttendanceReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search reports by course code...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF667eea),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.date_range, color: Color(0xFF667eea)),
                onPressed: () async {
                  final reportsResponse = await _apiService
                      .fetchAttendanceReports(
                        startDate: '2023-01-01',
                        endDate: DateTime.now().toString().split(' ')[0],
                      );
                  if (reportsResponse['success'] && mounted) {
                    setState(() {
                      _attendanceReports = List<Map<String, dynamic>>.from(
                        reportsResponse['reports'] ?? [],
                      );
                    });
                    _showMessage('Reports filtered by date');
                  } else {
                    _showMessage('Failed to filter reports', isError: true);
                  }
                },
                tooltip: 'Filter by Date',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _attendanceReports.isEmpty
                  ? const Center(child: Text('No attendance reports available'))
                  : ListView.builder(
                      itemCount: _attendanceReports.length,
                      itemBuilder: (context, index) {
                        final report = _attendanceReports[index];
                        final double percentage = (report['percentage'] as num?)?.toDouble() ?? 0.0;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Course: ${report['course_code']} - ${report['course_name'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF667eea),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Date: ${report['date']} | Time: ${report['time'] ?? 'N/A'}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey[200],
                                  color: percentage > 75
                                      ? Colors.green
                                      : percentage > 50
                                          ? Colors.orange
                                          : Colors.red,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Present: ${report['present_count']}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Absent: ${report['absent_count']}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Total: ${report['total_students']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF667eea),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Export PDF',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () {
                                      _showMessage(
                                        'Exporting report for ${report['course_code']} to PDF...',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSystemSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'System Configuration',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF667eea),
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
                const Text(
                  'Attendance Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: const Text('Allowed Distance for Attendance'),
                  subtitle: const Text(
                    'Maximum distance (in meters) students can be from lecturer for attendance marking.',
                  ),
                  trailing: DropdownButton<int>(
                    value: 100,
                    items: const [
                      DropdownMenuItem(value: 25, child: Text('25m')),
                      DropdownMenuItem(value: 50, child: Text('50m')),
                      DropdownMenuItem(value: 100, child: Text('100m')),
                      DropdownMenuItem(value: 150, child: Text('150m')),
                      DropdownMenuItem(value: 200, child: Text('200m')),
                    ],
                    onChanged: (value) async {
                      final response = await _apiService.updateSystemSetting(
                        'max_distance',
                        value!,
                      );
                      _showMessage(
                        response['message'] ?? 'Distance updated',
                        isError: !response['success'],
                      );
                    },
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Enable Location Verification'),
                  subtitle: const Text(
                    'Require students to be within the specified location range to mark attendance.',
                  ),
                  value: true,
                  onChanged: (value) async {
                    final response = await _apiService.updateSystemSetting(
                      'location_verification',
                      value,
                    );
                    _showMessage(
                      response['message'] ?? 'Setting updated',
                      isError: !response['success'],
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Biometrics Enabled Globally'),
                  subtitle: const Text(
                    'Allow biometric authentication for all users.',
                  ),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) async {
                      final response = await _apiService.updateSystemSetting(
                        'global_biometrics',
                        value,
                      );
                      _showMessage(
                        response['message'] ?? 'Biometrics setting updated',
                        isError: !response['success'],
                      );
                    },
                  ),
                ),
              ],
            ),
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
                const Text(
                  'System Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Recent actions and errors will be displayed here.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddEditCourseDialog({Map<String, dynamic>? course}) {
    final isEdit = course != null;
    final courseCodeController = TextEditingController(
      text: course?['course_code'] ?? '',
    );
    final courseNameController = TextEditingController(
      text: course?['course_name'] ?? '',
    );
    final departmentController = TextEditingController(
      text: course?['department'] ?? '',
    );
    final lecturerIdController = TextEditingController(
      text: course?['lecturer_id']?.toString() ?? '',
    );
    final statusController = TextEditingController(
      text: course?['status'] ?? 'active',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Course' : 'Add New Course'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: courseCodeController,
                decoration: const InputDecoration(labelText: 'Course Code'),
              ),
              TextField(
                controller: courseNameController,
                decoration: const InputDecoration(labelText: 'Course Name'),
              ),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              TextField(
                controller: lecturerIdController,
                decoration: const InputDecoration(
                  labelText: 'Lecturer ID (optional)',
                ),
              ),
              TextField(
                controller: statusController,
                decoration: const InputDecoration(
                  labelText: 'Status (active/inactive)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCourse = {
                'course_code': courseCodeController.text,
                'course_name': courseNameController.text,
                'department': departmentController.text,
                'lecturer_id': lecturerIdController.text.isEmpty
                    ? null
                    : lecturerIdController.text,
                'status': statusController.text,
              };
              if (isEdit) {
                await _updateCourse(course['course_id'].toString(), newCourse);
              } else {
                await _addCourse(newCourse);
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String userType) {
    switch (userType.toLowerCase()) {
      case 'student':
        return Colors.blueAccent;
      case 'lecturer':
        return Colors.green;
      case 'admin':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }
}