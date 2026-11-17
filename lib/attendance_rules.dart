const validAttendanceStatuses = <String>{
  'hadir',
  'izin',
  'sakit',
  'alpa',
};

bool hasCompleteAttendance(
  Iterable<String> memberIds,
  Map<String, String> statuses,
) {
  return memberIds.every(
    (memberId) => validAttendanceStatuses.contains(statuses[memberId]),
  );
}
