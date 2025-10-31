<?php
error_reporting(0);
header('Content-Type: application/json');

include 'db_connection.php';

if ($conn->connect_error) {
    echo json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]);
    exit;
}

function generateToken($length = 64) {
    return bin2hex(random_bytes($length));
}

$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';

if (empty($email) || empty($password)) {
    echo json_encode(['status' => 'error', 'message' => 'Email and password are required.']);
    exit;
}

$stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode(['status' => 'error', 'message' => 'User not found.']);
    exit;
}

$user = $result->fetch_assoc();
$stmt->close();

if (password_verify($password, $user['userpassword'])) {
    $user_id = $user['id'];
    $user_type = $user['user_type'];
    
    // Generate a new token for every login
    $token = generateToken();

    // Update the token in the database
    $update_token_stmt = $conn->prepare("UPDATE users SET token = ? WHERE id = ?");
    $update_token_stmt->bind_param("si", $token, $user_id);
    $update_token_stmt->execute();
    $update_token_stmt->close();

    // Fetch role-specific details
    $details_query = "";
    switch ($user_type) {
        case 'student':
            $details_query = "SELECT * FROM students WHERE user_id = ?";
            break;
        case 'lecturer':
            $details_query = "SELECT * FROM lecturers WHERE user_id = ?";
            break;
        case 'admin':
            // For admin, also update the token in the admins table for consistency
            $update_admins_stmt = $conn->prepare("UPDATE admins SET token = ? WHERE user_id = ?");
            $update_admins_stmt->bind_param("si", $token, $user_id);
            $update_admins_stmt->execute();
            $update_admins_stmt->close();
            $details_query = "SELECT * FROM admins WHERE user_id = ?";
            break;
    }

    if (!empty($details_query)) {
        $details_stmt = $conn->prepare($details_query);
        $details_stmt->bind_param("i", $user_id);
        $details_stmt->execute();
        $details_result = $details_stmt->get_result();
        $role_details = $details_result->fetch_assoc();
        $details_stmt->close();
        // Merge user and role details
        if ($role_details) {
            $user = array_merge($user, $role_details);
        }
    }

    unset($user['userpassword']);

    echo json_encode([
        'status' => 'success',
        'message' => 'Login successful.',
        'user' => $user,
        'token' => $token
    ]);

} else {
    echo json_encode(['status' => 'error', 'message' => 'Invalid password.']);
}

$conn->close();
?>