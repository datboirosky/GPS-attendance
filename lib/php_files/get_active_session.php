<?php
error_reporting(0);
header('Content-Type: application/json');
include 'db_connection.php';

if (isset($_GET['course_code'])) {
    $course_code = $_GET['course_code'];

    // Find active attendance session for a specific course
    $session_stmt = $conn->prepare("
        SELECT c.course_code, c.course_name, s.start_time
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
        echo json_encode(['success' => true, 'session' => $session]);
    } else {
        echo json_encode(['success' => false, 'message' => 'No active attendance session for this course.']);
    }
    $session_stmt->close();

} else {
    echo json_encode(['success' => false, 'message' => 'course_code not provided']);
}

$conn->close();
?>