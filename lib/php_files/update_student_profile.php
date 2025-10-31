<?php
include 'db_connect.php';

header('Content-Type: application/json');
$response = ['success' => false, 'message' => 'An unknown error occurred.'];

$data = json_decode(file_get_contents('php://input'), true);

$student_id = $data['student_id'] ?? null;
$updates = $data['updates'] ?? null;

if (!$student_id || !$updates || !is_array($updates)) {
    $response['message'] = 'Invalid input: student_id and updates are required.';
    echo json_encode($response);
    exit;
}

$user_columns_whitelist = ['fullname', 'email'];
$student_columns_whitelist = ['department', 'year'];

$user_updates = [];
$student_updates = [];

foreach ($updates as $key => $value) {
    if (in_array($key, $user_columns_whitelist)) {
        $user_updates[$key] = $value;
    }
    if (in_array($key, $student_columns_whitelist)) {
        $student_updates[$key] = $value;
    }
}

if (empty($user_updates) && empty($student_updates)) {
    $response['message'] = 'No valid fields to update.';
    echo json_encode($response);
    exit;
}

$conn->begin_transaction();

try {
    $stmt = $conn->prepare("SELECT user_id FROM students WHERE student_id = ?");
    if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);
    
    $stmt->bind_param("s", $student_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception("Student not found with id: " . $student_id);
    }
    $user_id = $result->fetch_assoc()['user_id'];
    $stmt->close();

    if (!empty($user_updates)) {
        $set_clauses = [];
        $params = [];
        $types = "";
        foreach ($user_updates as $key => $value) {
            $set_clauses[] = "$key = ?";
            $params[] = $value;
            $types .= "s";
        }
        $params[] = $user_id;
        $types .= "i";

        $sql = "UPDATE users SET " . implode(', ', $set_clauses) . " WHERE id = ?";
        $stmt = $conn->prepare($sql);
        if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);
        
        $stmt->bind_param($types, ...$params);
        if (!$stmt->execute()) {
            throw new Exception("Failed to update user data: " . $stmt->error);
        }
        $stmt->close();
    }

    if (!empty($student_updates)) {
        $set_clauses = [];
        $params = [];
        $types = "";
        foreach ($student_updates as $key => $value) {
            $set_clauses[] = "$key = ?";
            $params[] = $value;
            $types .= "s";
        }
        $params[] = $student_id;
        $types .= "s";

        $sql = "UPDATE students SET " . implode(', ', $set_clauses) . " WHERE student_id = ?";
        $stmt = $conn->prepare($sql);
        if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);

        $stmt->bind_param($types, ...$params);
        if (!$stmt->execute()) {
            throw new Exception("Failed to update student data: " . $stmt->error);
        }
        $stmt->close();
    }

    $conn->commit();
    $response['success'] = true;
    $response['message'] = 'Profile updated successfully.';

} catch (Exception $e) {
    $conn->rollback();
    $response['message'] = $e->getMessage();
}

echo json_encode($response);
$conn->close();
?>