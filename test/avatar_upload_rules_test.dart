import 'package:flutter_test/flutter_test.dart';
import 'package:marawis_smpn99/avatar_upload_rules.dart';

void main() {
  group('avatarExtensionForFileName', () {
    test('accepts supported image extensions case-insensitively', () {
      expect(avatarExtensionForFileName('profile.JPG'), 'jpg');
      expect(avatarExtensionForFileName('profile.jpeg'), 'jpg');
      expect(avatarExtensionForFileName('profile.PNG'), 'png');
      expect(avatarExtensionForFileName('profile.webp'), 'webp');
    });

    test('rejects unsupported or missing extensions', () {
      expect(avatarExtensionForFileName('profile.gif'), isNull);
      expect(avatarExtensionForFileName('profile'), isNull);
      expect(avatarExtensionForFileName('profile.png.exe'), isNull);
    });
  });

  group('isAvatarFileSizeValid', () {
    test('accepts positive files up to and including 5 MB', () {
      expect(isAvatarFileSizeValid(1), isTrue);
      expect(isAvatarFileSizeValid(maxAvatarFileSizeBytes), isTrue);
    });

    test('rejects empty files and files larger than 5 MB', () {
      expect(isAvatarFileSizeValid(0), isFalse);
      expect(isAvatarFileSizeValid(maxAvatarFileSizeBytes + 1), isFalse);
      expect(isAvatarFileSizeValid(-1), isFalse);
    });
  });
}
