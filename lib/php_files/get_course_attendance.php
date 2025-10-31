<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['student_id']) && isset($data['course_code'])) {
    $student_id = $data['student_id'];
    $course_code = $data['course_code'];

    $stmt = $conn->prepare("SELECT timestamp, status FROM attendance WHERE student_id = ? AND course_code = ? ORDER BY timestamp DESC");
    $stmt->bind_param("ss", $student_id, $course_code);
    $stmt->execute();
    $result = $stmt->get_result();

    $attendance = [];
    while ($row = $result->fetch_assoc()) {
        $attendance[] = [
            'date' => date('Y-m-d', strtotime($row['timestamp'])),
            'time' => date('H:i', strtotime($row['timestamp'])),
            'status' => $row['status']
        ];
    }

    echo json_encode(['success' => true, 'attendance' => $attendance]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'student_id or course_code not provided']);
}

$conn->close();
?>