<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

// Read the JSON input from the POST request
$data = json_decode(file_get_contents('php://input'), true);

$user_id = $data['user_id'] ?? null;
$date = $data['date'] ?? null;

if (isset($user_id) && isset($date)) {

    $stmt = $conn->prepare("
        SELECT 
            c.course_name as course, 
            s.schedule_time as time, 
            s.notes as room,
            'scheduled' as status
        FROM schedules s
        JOIN courses c ON s.course_id = c.course_id
        JOIN enrollments e ON c.course_id = e.course_id
        WHERE e.user_id = ? AND s.schedule_date = ?
        ORDER BY s.schedule_time ASC
    ");

    $stmt->bind_param("is", $user_id, $date);
    $stmt->execute();
    $result = $stmt->get_result();

    $schedule = [];
    while ($row = $result->fetch_assoc()) {
        $row['time'] = date('h:i A', strtotime($row['time']));
        $schedule[] = $row;
    }
    $stmt->close();

    if (!empty($schedule)) {
        // If we found a schedule for the student, return it.
        echo json_encode(['success' => true, 'schedule' => $schedule]);
    } else {
        // If no schedule was found for the student, check if ANY schedules exist for today for debugging.
        $debug_stmt = $conn->prepare("SELECT * FROM schedules WHERE schedule_date = ?");
        $debug_stmt->bind_param("s", $date);
        $debug_stmt->execute();
        $debug_result = $debug_stmt->get_result();

        if ($debug_result->num_rows > 0) {
            // Schedules exist for today, but the student is not enrolled in them.
            echo json_encode([
                'success' => true, 
                'schedule' => [],
                'debug_message' => 'Schedules for today were found, but you are not enrolled in any of them. Please check the enrollments table in your database.'
            ]);
        } else {
            // No schedules exist for today at all.
            echo json_encode([
                'success' => true,
                'schedule' => [],
                'debug_message' => 'No schedules have been created by any lecturer for today.'
            ]);
        }
        $debug_stmt->close();
    }

} else {
    echo json_encode(['success' => false, 'message' => 'user_id or date not provided']);
}

$conn->close();
?>
