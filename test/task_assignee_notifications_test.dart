import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/task_assignee_notifications.dart';

void main() {
  group('buildTaskAssigneeNotifications', () {
    test('notifies the assignee when a new task is assigned', () {
      final rows = buildTaskAssigneeNotifications(
        isNewTask: true,
        previousAssigneeId: null,
        nextAssigneeId: 'member-a',
        taskId: 12,
        taskTitle: 'Siapkan perlengkapan',
        dueDateLabel: '20/11/2026',
      );

      expect(rows, hasLength(1));
      expect(rows.single['user_id'], 'member-a');
      expect(rows.single['related_type'], 'program_task');
      expect(rows.single['related_id'], 12);
    });

    test('notifies both members when a task is reassigned', () {
      final rows = buildTaskAssigneeNotifications(
        isNewTask: false,
        previousAssigneeId: 'member-a',
        nextAssigneeId: 'member-b',
        taskId: 12,
        taskTitle: 'Siapkan perlengkapan',
        dueDateLabel: '20/11/2026',
      );

      expect(rows, hasLength(2));
      expect(rows.map((row) => row['user_id']), ['member-b', 'member-a']);
      expect(rows.first['title'], 'Tugas dialihkan kepadamu');
      expect(rows.last['title'], 'Tugas dialihkan');
    });

    test('does not notify again when the assignee is unchanged', () {
      final rows = buildTaskAssigneeNotifications(
        isNewTask: false,
        previousAssigneeId: 'member-a',
        nextAssigneeId: 'member-a',
        taskId: 12,
        taskTitle: 'Siapkan perlengkapan',
        dueDateLabel: '20/11/2026',
      );

      expect(rows, isEmpty);
    });

    test('notifies the previous assignee when a task becomes unassigned', () {
      final rows = buildTaskAssigneeNotifications(
        isNewTask: false,
        previousAssigneeId: 'member-a',
        nextAssigneeId: null,
        taskId: 12,
        taskTitle: 'Siapkan perlengkapan',
        dueDateLabel: 'Tanpa tenggat',
      );

      expect(rows, hasLength(1));
      expect(rows.single['user_id'], 'member-a');
      expect(rows.single['title'], 'Tugas dialihkan');
    });

    test('does not notify when a new task is unassigned', () {
      final rows = buildTaskAssigneeNotifications(
        isNewTask: true,
        previousAssigneeId: null,
        nextAssigneeId: null,
        taskId: 12,
        taskTitle: 'Siapkan perlengkapan',
        dueDateLabel: 'Tanpa tenggat',
      );

      expect(rows, isEmpty);
    });
  });
}
