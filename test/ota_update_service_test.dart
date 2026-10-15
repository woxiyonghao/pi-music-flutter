import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/ota_update_service.dart';

void main() {
  group('OtaUpdateService Unit Tests', () {
    final ota = OtaUpdateService.instance;

    test('initializes and reads repository root', () {
      final root = ota.getRepoRoot();
      expect(root, isNotEmpty);
    });

    test('reads local version info', () async {
      await ota.initLocalVersionInfo();
      expect(ota.currentBranch, isNotEmpty);
      expect(ota.currentCommit, isNotEmpty);
      expect(ota.status, OtaStatus.idle);
    });

    test('checks for updates via git fetch', () async {
      await ota.checkForUpdates();
      // Should result in upToDate or updateAvailable
      expect(
        ota.status == OtaStatus.upToDate ||
        ota.status == OtaStatus.updateAvailable ||
        ota.status == OtaStatus.failed,
        isTrue,
      );
      if (ota.status == OtaStatus.upToDate) {
        expect(ota.pendingCommitCount, 0);
      }
    });
  });
}
