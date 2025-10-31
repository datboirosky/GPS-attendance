<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['course_code']) && isset($data['lecturer_id'])) {
    $course_code = $data['course_code'];
    $lecturer_id = $data['lecturer_id'];

    $stmt = $conn->prepare("SELECT is_open FROM attendance_sessions WHERE course_code = ? AND lecturer_id = ? ORDER BY start_time DESC LIMIT 1");
    $stmt->bind_param("ss", $course_code, $lecturer_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $session = $result->fetch_assoc();
        echo json_encode(['success' => true, 'is_open' => (bool)$session['is_open']]);
    } else {
        echo json_encode(['success' => true, 'is_open' => false]);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Incomplete data provided']);
}

$conn->close();
?>