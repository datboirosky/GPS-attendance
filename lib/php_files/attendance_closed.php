<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Read the JSON input
$data = json_decode(file_get_contents('php://input'), true);

$course_code = $data['course_code'] ?? null;
$lecturer_id = $data['lecturer_id'] ?? null;

if (!empty($course_code) && !empty($lecturer_id)) {
    $end_time = date('Y-m-d H:i:s');

    // 1. Get course_id from course_code
    $stmt = $conn->prepare("SELECT course_id FROM courses WHERE course_code = ?");
    $stmt->bind_param("s", $course_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $course = $result->fetch_assoc();
        $course_id = $course['course_id'];
        $stmt->close();

        // 2. Update attendance_sessions
        $stmt = $conn->prepare("UPDATE attendance_sessions SET is_open = 0, end_time = ? WHERE course_id = ? AND lecturer_id = ? AND is_open = 1");
        $stmt->bind_param("sii", $end_time, $course_id, $lecturer_id);

        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                echo json_encode(['success' => true, 'message' => 'Attendance session closed']);
            } else {
                echo json_encode(['success' => false, 'message' => 'No open attendance session found for this course and lecturer.']);
            }
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to close attendance session']);
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