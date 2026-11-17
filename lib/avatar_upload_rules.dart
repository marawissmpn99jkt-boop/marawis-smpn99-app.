const maxAvatarFileSizeBytes = 5 * 1024 * 1024;

String? avatarExtensionForFileName(String fileName) {
  final normalized = fileName.trim().toLowerCase();
  if (normalized.endsWith('.png')) return 'png';
  if (normalized.endsWith('.webp')) return 'webp';
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'jpg';
  }
  return null;
}

bool isAvatarFileSizeValid(int byteLength) {
  return byteLength > 0 && byteLength <= maxAvatarFileSizeBytes;
}
