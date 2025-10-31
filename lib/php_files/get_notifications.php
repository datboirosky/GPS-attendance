<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['student_id'])) {
    $student_id = $data['student_id'];
    $limit = isset($data['limit']) ? (int)$data['limit'] : 20;

    $stmt = $conn->prepare("SELECT notification_id, message, created_at, is_read FROM notifications WHERE student_id = ? ORDER BY created_at DESC LIMIT ?");
    $stmt->bind_param("si", $student_id, $limit);
    $stmt->execute();
    $result = $stmt->get_result();

    $notifications = [];
    while ($row = $result->fetch_assoc()) {
        $notifications[] = $row;
    }

    echo json_encode(['success' => true, 'notifications' => $notifications]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'student_id not provided']);
}

$conn->close();
?>