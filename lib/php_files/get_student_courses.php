<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

if (isset($_GET['user_id'])) {
    $user_id = $_GET['user_id'];

    $stmt = $conn->prepare("SELECT c.course_id, c.course_code, c.course_name FROM courses c JOIN enrollments e ON c.course_id = e.course_id WHERE e.user_id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $courses = [];
    while ($row = $result->fetch_assoc()) {
        $courses[] = $row;
    }

    echo json_encode(['success' => true, 'courses' => $courses]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'user_id not provided']);
}

$conn->close();
?>