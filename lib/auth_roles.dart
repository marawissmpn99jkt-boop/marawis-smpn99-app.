/// Returns the staff role that must pass second-password verification.
///
/// A pending role represents a deliberate staff choice on the login screen.
/// A staff role already assigned in the database always requires verification,
/// even when the user selected the member login option.
String? requiredStaffVerificationRole({
  required String profileRole,
  String? pendingRole,
}) {
  if (pendingRole == 'pengurus' || pendingRole == 'pembina') {
    return pendingRole;
  }
  if (profileRole == 'pengurus' || profileRole == 'pembina') {
    return profileRole;
  }
  return null;
}
