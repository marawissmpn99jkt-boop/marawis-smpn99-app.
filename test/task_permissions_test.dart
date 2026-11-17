import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/task_permissions.dart';

void main() {
  group('canUpdateAssignedTaskStatus', () {
    test('admins can update any task status', () {
      expect(
        canUpdateAssignedTaskStatus(
          isAdmin: true,
          assignedTo: 'member-a',
          currentUserId: 'member-b',
        ),
        isTrue,
      );
    });

    test('the assigned member can update their own task status', () {
      expect(
        canUpdateAssignedTaskStatus(
          isAdmin: false,
          assignedTo: 'member-a',
          currentUserId: 'member-a',
        ),
        isTrue,
      );
    });

    test('another member cannot update the task status', () {
      expect(
        canUpdateAssignedTaskStatus(
          isAdmin: false,
          assignedTo: 'member-a',
          currentUserId: 'member-b',
        ),
        isFalse,
      );
    });

    test('unassigned tasks cannot be updated by members', () {
      expect(
        canUpdateAssignedTaskStatus(
          isAdmin: false,
          assignedTo: null,
          currentUserId: 'member-a',
        ),
        isFalse,
      );
    });

    test('a signed-out user cannot update an assigned task', () {
      expect(
        canUpdateAssignedTaskStatus(
          isAdmin: false,
          assignedTo: 'member-a',
          currentUserId: null,
        ),
        isFalse,
      );
    });
  });
}
