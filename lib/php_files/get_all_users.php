<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Function to get the token from the Authorization header
function getBearerToken() {
    $authHeader = null;
    if (isset($_SERVER['Authorization'])) {
        $authHeader = $_SERVER['Authorization'];
    } else if (isset($_SERVER['HTTP_AUTHORIZATION'])) { // Nginx or fast CGI
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
    } else if (function_exists('apache_request_headers')) {
        $requestHeaders = apache_request_headers();
        if (isset($requestHeaders['Authorization'])) {
            $authHeader = $requestHeaders['Authorization'];
        }
    }

    if ($authHeader !== null) {
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            return $matches[1];
        }
    }
    return null;
}

// Function to validate the admin token
function validateAdminToken($conn, $token) {
    if ($token === null) {
        return false;
    }
    // Validate the token against the users table and ensure the user is an admin.
    $stmt = $conn->prepare("SELECT id FROM users WHERE token = ? AND user_type = 'admin'");
    $stmt->bind_param("s", $token);
    $stmt->execute();
    $stmt->store_result();
    $isValid = $stmt->num_rows > 0;
    $stmt->close();
    return $isValid;
}

$token = getBearerToken();

if (!validateAdminToken($conn, $token)) {
    http_response_code(401); // Unauthorized
    echo json_encode(['success' => false, 'message' => 'Unauthorized: Invalid or missing admin token.']);
    $conn->close();
    exit;
}

// Fetch all users. This query joins the users table with the specific role tables.
$sql = "
    SELECT 
        u.id, 
        u.fullname, 
        u.email, 
        u.user_type, 
        u.department, 
        u.status,
        s.student_number, 
        s.year,
        l.lecturer_number,
        a.admin_number
    FROM users u
    LEFT JOIN students s ON u.id = s.user_id AND u.user_type = 'student'
    LEFT JOIN lecturers l ON u.id = l.user_id AND u.user_type = 'lecturer'
    LEFT JOIN admins a ON u.id = a.user_id AND u.user_type = 'admin'
    ORDER BY u.fullname;
";

$result = $conn->query($sql);

if ($result) {
    $users = [];
    while ($row = $result->fetch_assoc()) {
        $users[] = $row;
    }
    echo json_encode(['success' => true, 'users' => $users]);
} else {
    http_response_code(500); // Internal Server Error
    echo json_encode(['success' => false, 'message' => 'Database query failed: ' . $conn->error]);
}

$conn->close();
?>
