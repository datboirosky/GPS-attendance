<?php
header('Content-Type: application/json');
require_once 'db_connect.php';
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

if (!$userId) {
    echo json_encode(['success' => false, 'message' => 'User ID is required']);
    exit;
}

// Generate a new random password
$newPassword = bin2hex(random_bytes(8)); // 16 characters long
$hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);

// Update user password
$stmt = $conn->prepare("UPDATE users SET userpassword = ? WHERE id = ?");
$stmt->bind_param('si', $hashedPassword, $userId);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        // In a real app, you would email this password to the user.
        // For this example, we return it in the response.
        echo json_encode([
            'success' => true, 
            'message' => 'Password has been reset successfully. The new password is: ' . $newPassword
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'User not found']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to reset password: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
