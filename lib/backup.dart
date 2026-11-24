import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'state.dart';

/// Save / open the backup as a real .json file (Android, iOS, Windows, web).
///
/// Written for file_picker 12 and newer, where the old `FilePicker.platform`
/// API no longer exists: the methods are static (`FilePicker.saveFile`,
/// `FilePicker.pickFile`) and file contents are read with `readAsBytes()`.
class BackupFiles {
  static bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String fileName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'bosalty-backup-${n.year}-${two(n.month)}-${two(n.day)}.json';
  }

  /// Returns true if the file was saved, false if the user cancelled.
  static Future<bool> save(AppState s) async {
    final bytes = Uint8List.fromList(utf8.encode(s.exportBackupJson()));
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Bosalty backup',
      fileName: fileName(),
      bytes: bytes,
    );
    if (kIsWeb) return true; // the browser downloads it
    if (saved == null) return false; // the user cancelled
    if (!_mobile) {
      // Desktop: file_picker 12+ writes the bytes itself. This is only a safety net
      // in case the chosen file is not there, so a backup is never silently lost.
      try {
        final f = File(saved.toFilePath());
        if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
      } catch (_) {}
    }
    return true;
  }

  /// Lets the user pick a backup file and returns its text (null if cancelled).
  static Future<String?> pickText() async {
    final f = await FilePicker.pickFile();
    if (f == null) return null;
    final b = await f.readAsBytes();
    return utf8.decode(b, allowMalformed: true);
  }
}
