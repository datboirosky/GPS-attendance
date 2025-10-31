<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['notification_id']) && isset($data['student_id'])) {
    $notification_id = $data['notification_id'];
    $student_id = $data['student_id'];

    $stmt = $conn->prepare("UPDATE notifications SET is_read = TRUE WHERE notification_id = ? AND student_id = ?");
    $stmt->bind_param("is", $notification_id, $student_id);

    if ($stmt->execute()) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to mark notification as read']);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'notification_id or student_id not provided']);
}

$conn->close();
?>