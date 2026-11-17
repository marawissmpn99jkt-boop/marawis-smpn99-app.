List<Map<String, dynamic>> buildTaskAssigneeNotifications({
  required bool isNewTask,
  required String? previousAssigneeId,
  required String? nextAssigneeId,
  required int taskId,
  required String taskTitle,
  required String dueDateLabel,
}) {
  final previous = previousAssigneeId?.trim();
  final next = nextAssigneeId?.trim();
  final rows = <Map<String, dynamic>>[];

  if (next != null &&
      next.isNotEmpty &&
      (isNewTask || next != previous)) {
    rows.add({
      'user_id': next,
      'title': isNewTask ? 'Tugas baru untukmu' : 'Tugas dialihkan kepadamu',
      'body': 'Kamu ditugaskan pada tugas "$taskTitle". Tenggat: $dueDateLabel.',
      'related_type': 'program_task',
      'related_id': taskId,
    });
  }

  if (!isNewTask &&
      previous != null &&
      previous.isNotEmpty &&
      previous != next) {
    rows.add({
      'user_id': previous,
      'title': 'Tugas dialihkan',
      'body': 'Tugas "$taskTitle" tidak lagi menjadi tanggung jawabmu.',
      'related_type': 'program_task',
      'related_id': taskId,
    });
  }

  return rows;
}
