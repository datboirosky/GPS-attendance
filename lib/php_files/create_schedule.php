<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Read the JSON input
$data = json_decode(file_get_contents('php://input'), true);

$course_code = $data['course_code'] ?? null;
$lecturer_id = $data['lecturer_id'] ?? null;
$schedule_date = $data['schedule_date'] ?? null;
$schedule_time = $data['schedule_time'] ?? null;
$notes = $data['notes'] ?? '';

if (isset($course_code) && isset($lecturer_id) && isset($schedule_date) && isset($schedule_time)) {
    // 1. Get course_id from course_code
    $stmt = $conn->prepare("SELECT course_id FROM courses WHERE course_code = ?");
    $stmt->bind_param("s", $course_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $course = $result->fetch_assoc();
        $course_id = $course['course_id'];
        $stmt->close();

        // 2. Insert into schedules
        $stmt = $conn->prepare("INSERT INTO schedules (course_id, lecturer_id, schedule_date, schedule_time, notes) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("iisss", $course_id, $lecturer_id, $schedule_date, $schedule_time, $notes);

        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Schedule created successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to create schedule']);
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