<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['student_id']) && isset($data['course_code']) && isset($data['date']) && isset($data['description'])) {
    $student_id = $data['student_id'];
    $course_code = $data['course_code'];
    $date = $data['date'];
    $description = $data['description'];
    $submitted_at = date('Y-m-d H:i:s');

    $stmt = $conn->prepare("INSERT INTO attendance_issues (student_id, course_code, date, description, submitted_at) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("sssss", $student_id, $course_code, $date, $description, $submitted_at);

    if ($stmt->execute()) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to submit issue']);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Incomplete data provided']);
}

$conn->close();
?>