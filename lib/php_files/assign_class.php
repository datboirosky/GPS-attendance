<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Read the JSON input
$data = json_decode(file_get_contents('php://input'), true);

$lecturer_id = $data['lecturer_id'] ?? null;
$course_code = $data['class_identifier'] ?? null;

if (!empty($lecturer_id) && !empty($course_code)) {
    // 1. Get course_id from course_code
    $stmt = $conn->prepare("SELECT course_id FROM courses WHERE course_code = ?");
    $stmt->bind_param("s", $course_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $course = $result->fetch_assoc();
        $course_id = $course['course_id'];
        $stmt->close();

        // Check if already assigned
        $check_stmt = $conn->prepare("SELECT * FROM assigned_courses WHERE lecturer_id = ? AND course_id = ?");
        $check_stmt->bind_param("ii", $lecturer_id, $course_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();

        if ($check_result->num_rows > 0) {
            echo json_encode(['success' => false, 'message' => 'Course already assigned to this lecturer']);
            $check_stmt->close();
            $conn->close();
            exit;
        }
        $check_stmt->close();


        // 2. Insert into assigned_courses
        $stmt = $conn->prepare("INSERT INTO assigned_courses (lecturer_id, course_id) VALUES (?, ?)");
        $stmt->bind_param("ii", $lecturer_id, $course_id);

        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Class assigned successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to assign class']);
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