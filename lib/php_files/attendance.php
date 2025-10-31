<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Function to calculate distance between two points using Haversine formula
function haversine_distance($lat1, $lon1, $lat2, $lon2) {
    $earth_radius = 6371; // in kilometers

    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);

    $a = sin($dLat / 2) * sin($dLat / 2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) * sin($dLon / 2);
    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
    $distance = $earth_radius * $c;

    return $distance * 1000; // convert to meters
}

$user_id = $_POST['user_id'] ?? '';
$course_code = $_POST['course_code'] ?? '';
$student_lat = $_POST['latitude'] ?? null;
$student_lon = $_POST['longitude'] ?? null;

if (empty($user_id) || empty($course_code)) {
    echo json_encode(['success' => false, 'message' => 'User ID and course code are required.']);
    exit;
}

// Get system settings for location verification
$location_verification = true; // Default
$max_distance = 100; // Default in meters

$settings_stmt = $conn->prepare("SELECT setting_value FROM system_settings WHERE setting_name = 'location_verification'");
$settings_stmt->execute();
$result = $settings_stmt->get_result();
if ($row = $result->fetch_assoc()) {
    $location_verification = ($row['setting_value'] === 'true');
}
$settings_stmt->close();

$settings_stmt = $conn->prepare("SELECT setting_value FROM system_settings WHERE setting_name = 'max_distance'");
$settings_stmt->execute();
$result = $settings_stmt->get_result();
if ($row = $result->fetch_assoc()) {
    $max_distance = (int)$row['setting_value'];
}
$settings_stmt->close();


// Find active attendance session for the course
$session_stmt = $conn->prepare("
    SELECT s.session_id, s.latitude, s.longitude
    FROM attendance_sessions s
    JOIN courses c ON s.course_id = c.course_id
    WHERE c.course_code = ? AND s.is_open = 1
    ORDER BY s.start_time DESC
    LIMIT 1
");
$session_stmt->bind_param("s", $course_code);
$session_stmt->execute();
$session_result = $session_stmt->get_result();

if ($session_result->num_rows > 0) {
    $session = $session_result->fetch_assoc();
    $session_id = $session['session_id'];
    $lecturer_lat = $session['latitude'];
    $lecturer_lon = $session['longitude'];

    // Location verification logic
    if ($location_verification) {
        if ($student_lat === null || $student_lon === null) {
            echo json_encode(['success' => false, 'message' => 'Location not provided.']);
            exit;
        }

        if ($lecturer_lat === null || $lecturer_lon === null) {
            // If lecturer location is not set, we can either deny or allow.
            // For this case, we will allow, but a stricter implementation might deny.
            // echo json_encode(['success' => false, 'message' => 'Lecturer location not available for this session.']);
            // exit;
        } else {
            $distance = haversine_distance($student_lat, $student_lon, $lecturer_lat, $lecturer_lon);

            if ($distance > $max_distance) {
                echo json_encode(['success' => false, 'message' => "You are too far from the class location to mark attendance. Distance: " . round($distance) . "m"]);
                exit;
            }
        }
    }

    // Check if attendance already marked
    $check_stmt = $conn->prepare("SELECT attendance_id FROM attendance WHERE session_id = ? AND user_id = ?");
    $check_stmt->bind_param("ii", $session_id, $user_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows > 0) {
        echo json_encode(['success' => false, 'message' => 'Attendance already marked for this session.']);
        $check_stmt->close();
        exit;
    }
    $check_stmt->close();

    // Insert attendance record
    $insert_stmt = $conn->prepare("
        INSERT INTO attendance (session_id, user_id, status, latitude, longitude)
        VALUES (?, ?, 'present', ?, ?)
    ");
    $insert_stmt->bind_param("iidd", $session_id, $user_id, $student_lat, $student_lon);

    if ($insert_stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Attendance marked successfully.']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to mark attendance.']);
    }
    $insert_stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'No active attendance session for this course.']);
}

$session_stmt->close();
$conn->close();
?>