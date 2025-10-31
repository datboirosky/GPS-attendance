<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

if (isset($_GET['user_id'])) {
    $user_id = $_GET['user_id'];
    $limit = 5; // Small limit for recent attendance

    $stmt = $conn->prepare("SELECT c.course_name as course, a.timestamp, a.status FROM attendance a JOIN attendance_sessions s ON a.session_id = s.session_id JOIN courses c ON s.course_id = c.course_id WHERE a.user_id = ? ORDER BY a.timestamp DESC LIMIT ?");
    $stmt->bind_param("ii", $user_id, $limit);
    $stmt->execute();
    $result = $stmt->get_result();

    $attendance = [];
    while ($row = $result->fetch_assoc()) {
        $attendance[] = [
            'course' => $row['course'],
            'date' => date('Y-m-d', strtotime($row['timestamp'])),
            'time' => date('H:i', strtotime($row['timestamp'])),
            'status' => $row['status']
        ];
    }

    echo json_encode(['success' => true, 'attendance' => $attendance]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'user_id not provided']);
}

$conn->close();
?>