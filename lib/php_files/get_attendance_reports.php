<?php
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

// Basic query to get attendance reports. 
// This can be expanded with date filtering.
$sql = "
    SELECT 
        c.course_code, 
        c.course_name,
        ar.date,
        ar.time,
        COUNT(ar.student_id) AS total_students,
        SUM(CASE WHEN ar.status = 'present' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN ar.status = 'absent' THEN 1 ELSE 0 END) AS absent_count,
        (SUM(CASE WHEN ar.status = 'present' THEN 1 ELSE 0 END) / COUNT(ar.student_id)) * 100 AS percentage
    FROM attendance_records ar
    JOIN courses c ON ar.course_id = c.course_id
    GROUP BY ar.course_id, ar.date, ar.time, c.course_code, c.course_name
    ORDER BY ar.date DESC, ar.time DESC;
";

$result = $conn->query($sql);

if ($result) {
    $reports = [];
    while ($row = $result->fetch_assoc()) {
        $reports[] = $row;
    }
    echo json_encode(['success' => true, 'reports' => $reports]);
} else {
    http_response_code(500); // Internal Server Error
    echo json_encode(['success' => false, 'message' => 'Database query failed: ' . $conn->error]);
}

$conn->close();
?>
