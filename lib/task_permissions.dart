bool canUpdateAssignedTaskStatus({
  required bool isAdmin,
  required String? assignedTo,
  required String? currentUserId,
}) {
  if (isAdmin) return true;
  return currentUserId != null &&
      currentUserId.isNotEmpty &&
      assignedTo == currentUserId;
}
