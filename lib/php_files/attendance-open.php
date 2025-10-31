<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Read the JSON input
$data = json_decode(file_get_contents('php://input'), true);

$course_code = $data['course_code'] ?? null;
$lecturer_id = $data['lecturer_id'] ?? null;
$latitude = $data['latitude'] ?? null;
$longitude = $data['longitude'] ?? null;

if (!empty($course_code) && !empty($lecturer_id) && isset($latitude) && isset($longitude)) {
    $start_time = date('Y-m-d H:i:s');

    // 1. Get course_id from course_code
    $stmt = $conn->prepare("SELECT course_id FROM courses WHERE course_code = ?");
    $stmt->bind_param("s", $course_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $course = $result->fetch_assoc();
        $course_id = $course['course_id'];
        $stmt->close();

        // 2. Insert into attendance_sessions
        $stmt = $conn->prepare("INSERT INTO attendance_sessions (course_id, lecturer_id, start_time, latitude, longitude, is_open) VALUES (?, ?, ?, ?, ?, 1)");
        $stmt->bind_param("iisdd", $course_id, $lecturer_id, $start_time, $latitude, $longitude);

        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Attendance session opened']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to open attendance session']);
        }
    } else {
        echo json_encode(['success' => false, 'message' => 'Course not found']);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Incomplete data provided']);
}

$conn->close();
?>