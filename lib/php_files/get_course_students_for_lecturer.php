<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

if (isset($_GET['course_code'])) {
    $course_code = $_GET['course_code'];

    $stmt = $conn->prepare("SELECT s.user_id, s.student_number, u.fullname AS full_name, u.email FROM students s JOIN users u ON s.user_id = u.id JOIN enrollments e ON s.user_id = e.user_id JOIN courses c ON e.course_id = c.course_id WHERE c.course_code = ?");
    $stmt->bind_param("s", $course_code);
    $stmt->execute();
    $result = $stmt->get_result();

    $students = [];
    while ($row = $result->fetch_assoc()) {
        $students[] = $row;
    }

    echo json_encode(['success' => true, 'students' => $students]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'course_code not provided']);
}

$conn->close();
?>