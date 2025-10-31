<?php
include 'db_connect.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (isset($data['student_id'])) {
    $student_id = $data['student_id'];

    $stmt = $conn->prepare("SELECT full_name, email, department, year FROM students WHERE student_id = ?");
    $stmt->bind_param("s", $student_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $profile = $result->fetch_assoc();
        echo json_encode(['success' => true, 'profile' => $profile]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Student not found']);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'student_id not provided']);
}

$conn->close();
?>