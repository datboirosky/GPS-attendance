<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Read the JSON input
$data = json_decode(file_get_contents('php://input'), true);
$lecturer_id = $data['lecturer_id'] ?? null;

if (!empty($lecturer_id)) {

    $stmt = $conn->prepare("SELECT c.course_id, c.course_code, c.course_name, c.department FROM courses c JOIN assigned_courses ac ON c.course_id = ac.course_id WHERE ac.lecturer_id = ?");
    $stmt->bind_param("i", $lecturer_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $courses = [];
    while ($row = $result->fetch_assoc()) {
        $courses[] = $row;
    }

    echo json_encode(['success' => true, 'courses' => $courses]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'lecturer_id not provided']);
}

$conn->close();
?>