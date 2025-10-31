<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['lecturer_id'])) {
    $lecturer_id = $data['lecturer_id'];
    $course_code = isset($data['course_code']) ? $data['course_code'] : null;
    $start_date = isset($data['start_date']) ? $data['start_date'] : null;
    $end_date = isset($data['end_date']) ? $data['end_date'] : null;

    $query = "SELECT a.attendance_id, a.student_id, s.full_name, a.course_code, c.course_name, a.timestamp, a.status FROM attendance a JOIN students s ON a.student_id = s.student_id JOIN courses c ON a.course_code = c.course_code WHERE c.lecturer_id = ?";

    $params = ['s', $lecturer_id];

    if ($course_code) {
        $query .= " AND a.course_code = ?";
        $params[0] .= 's';
        $params[] = $course_code;
    }

    if ($start_date) {
        $query .= " AND a.timestamp >= ?";
        $params[0] .= 's';
        $params[] = $start_date;
    }

    if ($end_date) {
        $query .= " AND a.timestamp <= ?";
        $params[0] .= 's';
        $params[] = $end_date;
    }

    $stmt = $conn->prepare($query);
    $stmt->bind_param(...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $reports = [];
    while ($row = $result->fetch_assoc()) {
        $reports[] = $row;
    }

    echo json_encode(['success' => true, 'reports' => $reports]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'lecturer_id not provided']);
}

$conn->close();
?>