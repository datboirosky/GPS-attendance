<?php
header('Content-Type: application/json');
require_once 'db_connection.php';
require_once 'vendor/autoload.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

// Verify Admin Token
if (!isset($_SERVER['HTTP_AUTHORIZATION'])) {
    echo json_encode(['success' => false, 'message' => 'Authorization header missing']);
    exit;
}

$authHeader = $_SERVER['HTTP_AUTHORIZATION'];
list(, $token) = explode(' ', $authHeader);

if (!$token) {
    echo json_encode(['success' => false, 'message' => 'Token not provided']);
    exit;
}

$secretKey = 'your_secret_key';

try {
    $decoded = JWT::decode($token, new Key($secretKey, 'HS256'));
    if ($decoded->user_type !== 'admin') {
        throw new Exception('Access denied');
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Invalid token: ' . $e->getMessage()]);
    exit;
}

// Get POST data
$data = json_decode(file_get_contents('php://input'), true);
$userId = $data['user_id'] ?? null;
$newStatus = $data['status'] ?? null;

if (!$userId || !$newStatus) {
    echo json_encode(['success' => false, 'message' => 'User ID and new status are required']);
    exit;
}

if (!in_array($newStatus, ['active', 'inactive'])) {
    echo json_encode(['success' => false, 'message' => 'Invalid status value']);
    exit;
}

// Update user status
$stmt = $conn->prepare("UPDATE users SET status = ? WHERE id = ?");
$stmt->bind_param('si', $newStatus, $userId);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode(['success' => true, 'message' => 'User status updated successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'User not found or status is already the same']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to update user status: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
