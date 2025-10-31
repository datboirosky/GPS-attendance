<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

if (isset($_POST['lecturer_id']) && isset($_POST['latitude']) && isset($_POST['longitude'])) {
    $lecturer_id = $_POST['lecturer_id'];
    $latitude = $_POST['latitude'];
    $longitude = $_POST['longitude'];

    $stmt = $conn->prepare("UPDATE lecturers SET latitude = ?, longitude = ? WHERE lecturer_id = ?");
    $stmt->bind_param("ddi", $latitude, $longitude, $lecturer_id);

    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Location updated successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to update location']);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Incomplete data provided']);
}

$conn->close();
?>