<?php
error_reporting(0);
include 'db_connection.php';

header('Content-Type: application/json');

if (isset($_GET['user_id'])) {
    $user_id = $_GET['user_id'];

    // Overall stats
    $stmt = $conn->prepare("SELECT COUNT(*) as total_classes, SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) as classes_attended FROM attendance WHERE user_id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $overall_stats = $result->fetch_assoc();

    $total_classes = $overall_stats['total_classes'];
    $classes_attended = $overall_stats['classes_attended'];
    $overall_rate = ($total_classes > 0) ? ($classes_attended / $total_classes) : 0;

    // Course-specific stats
    $stmt = $conn->prepare("SELECT c.course_code, c.course_name, COUNT(*) as total, SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) as attended FROM attendance a JOIN attendance_sessions s ON a.session_id = s.session_id JOIN courses c ON s.course_id = c.course_id WHERE a.user_id = ? GROUP BY c.course_code, c.course_name");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $course_stats = [];
    while ($row = $result->fetch_assoc()) {
        $course_rate = ($row['total'] > 0) ? ($row['attended'] / $row['total']) : 0;
        $course_stats[] = [
            'name' => $row['course_name'],
            'rate' => $course_rate
        ];
    }

    echo json_encode([
        'success' => true,
        'stats' => [
            'overall_rate' => $overall_rate,
            'classes_attended' => (int)$classes_attended,
            'total_classes' => (int)$total_classes,
            'courses' => $course_stats
        ]
    ]);

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'user_id not provided']);
}

$conn->close();
?>