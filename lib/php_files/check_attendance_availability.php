<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

if (isset($_GET['latitude']) && isset($_GET['longitude']) && isset($_GET['course_code'])) {
    $student_lat = $_GET['latitude'];
    $student_lon = $_GET['longitude'];
    $course_code = $_GET['course_code'];

    // Get max distance from system settings
    $setting_stmt = $conn->prepare("SELECT setting_value FROM system_settings WHERE setting_name = 'max_distance'");
    $setting_stmt->execute();
    $setting_result = $setting_stmt->get_result();
    $max_distance = $setting_result->fetch_assoc()['setting_value'] ?? 100; // Default to 100 meters
    $setting_stmt->close();

    // Find active attendance session for the given course
    $session_stmt = $conn->prepare("
        SELECT s.latitude, s.longitude
        FROM attendance_sessions s
        JOIN courses c ON s.course_id = c.course_id
        WHERE s.is_open = 1 AND c.course_code = ?
        ORDER BY s.start_time DESC
        LIMIT 1
    ");
    $session_stmt->bind_param("s", $course_code);
    $session_stmt->execute();
    $session_result = $session_stmt->get_result();

    if ($session_result->num_rows > 0) {
        $session = $session_result->fetch_assoc();
        $session_lat = $session['latitude'];
        $session_lon = $session['longitude'];

        if ($session_lat && $session_lon) {
            $distance = haversine_distance($student_lat, $student_lon, $session_lat, $session_lon);

            if ($distance <= $max_distance) {
                echo json_encode(['success' => true, 'available' => true]);
            } else {
                echo json_encode(['success' => true, 'available' => false, 'message' => 'You are too far from the class location.']);
            }
        } else {
            // If session location is not set, maybe default to available
            echo json_encode(['success' => true, 'available' => true, 'message' => 'Session location not set, availability granted by default.']);
        }
    } else {
        echo json_encode(['success' => false, 'available' => false, 'message' => 'No active attendance session for this course.']);
    }

    $session_stmt->close();
} else {
    echo json_encode(['success' => false, 'available' => false, 'message' => 'Required parameters not provided.']);
}

$conn->close();

function haversine_distance($lat1, $lon1, $lat2, $lon2) {
    $earth_radius = 6371000; // meters

    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);

    $a = sin($dLat / 2) * sin($dLat / 2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLon / 2) * sin($dLon / 2);
    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

    return $earth_radius * $c;
}
?>