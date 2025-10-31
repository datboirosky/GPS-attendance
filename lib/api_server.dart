import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = 'http://10.191.146.102/student_attendance/';

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode == 200) {
      if (response.headers['content-type']?.contains('application/json') ==
          true) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {
            'success': false,
            'message':
                'Error decoding JSON: $e, Response body: ${response.body}',
          };
        }
      } else {
        return {
          'success': false,
          'message':
              'Invalid response format: Expected JSON, but got ${response.headers['content-type']}',
        };
      }
    } else {
      // Try to decode the error response from the server for more details
      try {
        final errorData = jsonDecode(response.body);
        if (errorData != null && errorData['message'] != null) {
          return {
            'success': false,
            'message':
                'Server error (${response.statusCode}): ${errorData['message']}',
          };
        }
      } catch (e) {
        // Not a JSON response, fall back to generic error
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    }
  }

  Future<Map<String, dynamic>> register(Map<String, String> data) async {
    final url = Uri.parse('${baseUrl}register.php');
    try {
      final response = await http.post(url, body: data);
      final responseData = await _handleResponse(response);

      if (responseData['status'] == 'success') {
        final user = responseData['user'];
        final prefs = await SharedPreferences.getInstance();
        final userType = user['user_type'];

        await prefs.setString('user_data', jsonEncode(user));

        if (responseData.containsKey('token')) {
          await prefs.setString('${userType}_token', responseData['token']);
        }
      }

      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${baseUrl}login.php');
    try {
      final response = await http.post(
        url,
        body: {'email': email, 'password': password},
      );
      final data = await _handleResponse(response);
      if (data['status'] == 'success') {
        final user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        final userType = user['user_type']; // Use 'user_type' for consistency
        await prefs.setString('user_data', jsonEncode(user));
        if (data.containsKey('token')) {
          print('Saving token for $userType: ${data['token']}');
          await prefs.setString('${userType}_token', data['token']);
        }
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateBiometricsPreference(
    int userId,
    bool biometricsEnabled,
  ) async {
    final url = Uri.parse('${baseUrl}update_biometrics_preference.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'biometrics_enabled': biometricsEnabled ? 1 : 0,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchCourseStudentsForLecturer(
    String courseCode,
    String department,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}get_course_students_for_lecturer.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'course_code': courseCode, 'department': department}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchLecturerAttendanceReports({
    String? courseCode,
    String? startDate,
    String? endDate,
  }) async {
    final url = Uri.parse('${baseUrl}get_lecturer_attendance_reports.php');
    try {
      final token = await getLecturerToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Lecturer token missing. Please log in again.',
        };
      }

      final Map<String, String> body = {'token': token};
      if (courseCode != null) body['course_code'] = courseCode;
      if (startDate != null) body['start_date'] = startDate;
      if (endDate != null) body['end_date'] = endDate;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching lecturer reports: $e',
      };
    }
  }

  Future<Map<String, dynamic>> fetchLecturerCourses(
    String lecturerIdentifier,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}get_lecturer_courses.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'lecturer_id': lecturerIdentifier, 'token': token}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateLecturerLocation(
    String lecturerId,
    String department,
    double latitude,
    double longitude,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}update-lecturer-location.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lecturer_id': lecturerId,
          'department': department,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update location: $e'};
    }
  }

  Future<Map<String, dynamic>> openAttendanceSession(
    String courseCode,
    String lecturerId,
    double latitude,
    double longitude,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}attendance-open.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'course_code': courseCode,
          'lecturer_id': lecturerId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to open attendance session'};
    }
  }

  Future<Map<String, dynamic>> closeAttendanceSession(
    String courseCode,
    String lecturerId,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}attendance_closed.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'course_code': courseCode,
          'lecturer_id': lecturerId,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to close attendance session',
      };
    }
  }

  Future<Map<String, dynamic>> assignClassToLecturer(
    String lecturerId,
    String classIdentifier,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}assign_class.php');
    if (token.isEmpty) {
      return {'success': false, 'message': 'Missing token'};
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lecturer_id': lecturerId,
          'class_identifier': classIdentifier,
        }),
      );

      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to assign class: $e'};
    }
  }

  Future<Map<String, dynamic>> createSchedule(
    String courseCode,
    String lecturerId,
    String scheduleDate,
    String scheduleTime,
    String notes,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}create_schedule.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'course_code': courseCode,
          'lecturer_id': lecturerId,
          'schedule_date': scheduleDate,
          'schedule_time': scheduleTime,
          'notes': notes,
        }),
      );

      return await _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<String?> getAdminToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_token');
  }

  Future<String?> getLecturerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lecturer_token');
  }

  Future<String?> getStudentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('student_token');
  }

  Future<Map<String, dynamic>> fetchAllUsers() async {
    final url = Uri.parse('${baseUrl}get_all_users.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch users: $e'};
    }
  }

  Future<Map<String, dynamic>> updateUserStatus(
    String userId,
    String newStatus,
  ) async {
    final url = Uri.parse('${baseUrl}update_user_status.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId, 'status': newStatus}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update user status: $e'};
    }
  }

  Future<Map<String, dynamic>> resetUserPassword(String userId) async {
    final url = Uri.parse('${baseUrl}reset_user_password.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to reset user password: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final url = Uri.parse('${baseUrl}delete_user.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete user: $e'};
    }
  }

  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final url = Uri.parse('${baseUrl}update_user.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId, ...userData}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update user: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchAllCourses() async {
    final url = Uri.parse('${baseUrl}get_all_courses.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch courses: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchAllSchedules() async {
    final url = Uri.parse('${baseUrl}get_all_schedules.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch schedules: $e'};
    }
  }

  Future<Map<String, dynamic>> addCourse(
    Map<String, dynamic> courseData,
  ) async {
    final url = Uri.parse('${baseUrl}add_course.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(courseData),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to add course: $e'};
    }
  }

  Future<Map<String, dynamic>> updateCourse(
    String courseId,
    Map<String, dynamic> courseData,
  ) async {
    final url = Uri.parse('${baseUrl}update_course.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'course_id': courseId, ...courseData}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update course: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteCourse(String courseId) async {
    final url = Uri.parse('${baseUrl}delete_course.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'course_id': courseId}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete course: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchAttendanceReports({
    String? courseCode,
    String? startDate,
    String? endDate,
  }) async {
    final url = Uri.parse('${baseUrl}get_attendance_reports.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final Map<String, String> queryParams = {};
      if (courseCode != null) queryParams['course_code'] = courseCode;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = url.replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch attendance reports: $e',
      };
    }
  }

  Future<Map<String, dynamic>> fetchSystemSettings() async {
    final url = Uri.parse('${baseUrl}get_system_settings.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch system settings: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateSystemSetting(
    String settingName,
    dynamic settingValue,
  ) async {
    final url = Uri.parse('${baseUrl}update_system_setting.php');
    try {
      final token = await getAdminToken();
      if (token == null) {
        return {'success': false, 'message': 'Admin token missing.'};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'setting_name': settingName,
          'setting_value': settingValue,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update system setting: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getActiveSession(String courseCode) async {
    final url = Uri.parse(
      '${baseUrl}get_active_session.php?course_code=$courseCode',
    );
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getStudentProfile(String studentId) async {
    final url = Uri.parse('${baseUrl}get_student_profile.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateStudentProfile(
    String studentId,
    Map<String, dynamic> updates,
  ) async {
    final url = Uri.parse('${baseUrl}update_student_profile.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'updates': updates}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTodaysSchedule(String studentId) async {
    final url = Uri.parse('${baseUrl}get_schedule.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': studentId,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getAttendanceStats(String studentId) async {
    final url = Uri.parse('${baseUrl}get_attendance_stats.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getAttendanceHistory(
    String studentId, {
    int limit = 50,
  }) async {
    final url = Uri.parse('${baseUrl}get_attendance_history.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'limit': limit}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getRecentAttendance(
    String studentId, {
    int limit = 5,
  }) async {
    final url = Uri.parse('${baseUrl}get_recent_attendance.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'limit': limit}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> markAttendance(
    String studentId,
    String courseCode,
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse('${baseUrl}attendance.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'course_code': courseCode,
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> checkAttendanceAvailability(
    String courseCode,
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse('${baseUrl}check_attendance_availability.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'course_code': courseCode,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getStudentCourses(String studentId) async {
    final url = Uri.parse(
      '${baseUrl}get_student_courses.php?student_id=$studentId',
    );
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getCourseAttendance(
    String studentId,
    String courseCode,
  ) async {
    final url = Uri.parse('${baseUrl}get_course_attendance.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'course_code': courseCode}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitAttendanceIssue(
    String studentId,
    String courseCode,
    String date,
    String description,
  ) async {
    final url = Uri.parse('${baseUrl}submit_attendance_issue.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'course_code': courseCode,
          'date': date,
          'description': description,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getNotifications(
    String studentId, {
    int limit = 20,
  }) async {
    final url = Uri.parse('${baseUrl}get_notifications.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'limit': limit}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
    String studentId,
  ) async {
    final url = Uri.parse('${baseUrl}mark_notification_read.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notification_id': notificationId,
          'student_id': studentId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> checkOpenAttendance(String token) async {
    final url = Uri.parse('${baseUrl}check-attendance.php');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchLecturerSchedules(String token) async {
    final url = Uri.parse('${baseUrl}schedules.php');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'schedules': []};
    }
  }

  Future<Map<String, dynamic>> getAttendanceStatus(
    String courseCode,
    String department,
    String token,
  ) async {
    final url = Uri.parse('${baseUrl}get_attendance_status.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'course_code': courseCode, 'department': department}),
      );
      return await _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting attendance status: $e',
      };
    }
  }
}