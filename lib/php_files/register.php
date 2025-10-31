<?php
error_reporting(0); // Suppress warnings from being output in the response
include 'db_connection.php';

if ($conn->connect_error) {
    echo json_encode(['status' => 'error', 'message' => 'Connection failed: ' . $conn->connect_error]);
    exit;
}

header('Content-Type: application/json');

// Function to generate a secure random token
function generateToken($length = 64) {
    return bin2hex(random_bytes($length));
}

$user_type = $_POST['user_type'] ?? '';
$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';
$fullname = $_POST['fullname'] ?? '';
$department = $_POST['department'] ?? '';

if (empty($user_type) || empty($email) || empty($password) || empty($fullname)) {
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

// Check if email already exists
$stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
if (!$stmt->execute()) {
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $stmt->error]);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->store_result();
if ($stmt->num_rows > 0) {
    echo json_encode(['status' => 'error', 'message' => 'Email already registered.']);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->close();

$hashed_password = password_hash($password, PASSWORD_BCRYPT);
$token = null;
if ($user_type === 'admin') {
    $token = generateToken();
}

// Start transaction
$conn->begin_transaction();

try {
    // Insert into the main users table first (without department)
    $stmt = $conn->prepare("INSERT INTO users (email, userpassword, user_type, fullname, token) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("sssss", $email, $hashed_password, $user_type, $fullname, $token);
    
    if (!$stmt->execute()) {
        throw new Exception($stmt->error);
    }
    
    $user_id = $stmt->insert_id;
    $stmt->close();

    $specific_data = [];

    switch ($user_type) {
        case 'student':
            $student_number = $_POST['student_number'] ?? '';
            $year = $_POST['year'] ?? '';
            $stmt = $conn->prepare("INSERT INTO students (user_id, student_number, department, year) VALUES (?, ?, ?, ?)");
            $stmt->bind_param("isss", $user_id, $student_number, $department, $year);
            $specific_data = ['student_number' => $student_number, 'year' => $year];
            break;

        case 'lecturer':
            $lecturer_number = $_POST['lecturer_number'] ?? '';
            $stmt = $conn->prepare("INSERT INTO lecturers (user_id, lecturer_number, department) VALUES (?, ?, ?)");
            $stmt->bind_param("iss", $user_id, $lecturer_number, $department);
            $specific_data = ['lecturer_number' => $lecturer_number];
            break;

        case 'admin':
            $admin_number = $_POST['admin_number'] ?? '';
            $stmt = $conn->prepare("INSERT INTO admins (user_id, admin_number, department, token) VALUES (?, ?, ?, ?)");
            $stmt->bind_param("isss", $user_id, $admin_number, $department, $token);
            $specific_data = ['admin_number' => $admin_number];
            break;

        default:
            throw new Exception('Invalid user type.');
    }

    if (!$stmt->execute()) {
        throw new Exception($stmt->error);
    }
    $stmt->close();

    // If all queries were successful, commit the transaction
    $conn->commit();

    $user_data = [
        'id' => $user_id,
        'fullname' => $fullname,
        'email' => $email,
        'user_type' => $user_type,
        'department' => $department
    ] + $specific_data;

    $response = ['status' => 'success', 'message' => 'Registration successful.', 'user' => $user_data];
    if ($token) {
        $response['token'] = $token;
    }
    echo json_encode($response);

} catch (Exception $e) {
    // An error occurred, rollback the transaction
    $conn->rollback();
    echo json_encode(['status' => 'error', 'message' => 'Registration failed: ' . $e->getMessage()]);
}

$conn->close();
?>