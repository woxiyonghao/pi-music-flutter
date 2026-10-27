#!/usr/bin/env python3
"""Read-only audit of the installed app DB using Android's independent SQLite.

Requires Android SDK build-tools 35+, Java 17 and the same signing certificate as
the installed app (this repository currently signs Release with the debug key).
Builds a temporary instrumentation APK, audits private storage, then removes it.
No app data is exported, cleared or rewritten. Instrumentation restarts the app.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile


JAVA = r'''
package com.example.hide_player_flutter.database_audit;

import android.app.Activity;
import android.app.Instrumentation;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import java.io.File;
import java.io.FileInputStream;
import java.security.MessageDigest;
import org.json.JSONObject;

public final class DatabaseAudit extends Instrumentation {
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    private static long number(SQLiteDatabase db, String sql) {
        try (Cursor c = db.rawQuery(sql, null)) {
            if (!c.moveToFirst()) throw new IllegalStateException("No scalar row");
            return c.getLong(0);
        }
    }

    private static String text(SQLiteDatabase db, String sql) {
        try (Cursor c = db.rawQuery(sql, null)) {
            if (!c.moveToFirst()) throw new IllegalStateException("No text row");
            return c.getString(0);
        }
    }

    private static String digest(File file) throws Exception {
        if (!file.exists()) return "absent";
        MessageDigest hash = MessageDigest.getInstance("SHA-256");
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] buffer = new byte[65536];
            int count;
            while ((count = in.read(buffer)) != -1) hash.update(buffer, 0, count);
        }
        StringBuilder result = new StringBuilder();
        for (byte value : hash.digest()) result.append(String.format("%02x", value & 255));
        return result.toString();
    }

    private static void require(boolean ok, String message) {
        if (!ok) throw new IllegalStateException(message);
    }

    @Override public void onStart() {
        JSONObject report = new JSONObject();
        Bundle result = new Bundle();
        try {
            File database = new File(getTargetContext().getApplicationInfo().dataDir,
                "app_flutter/hifi_player/library.db");
            File wal = new File(database.getPath() + "-wal");
            require(database.isFile(), "Installed library.db is missing");
            String before = digest(database), beforeWal = digest(wal);
            long beforeWalSize = wal.length();
            report.put("database", database.getCanonicalPath());
            report.put("engine", "Android system SQLite (independent of audio_engine)");
            try (SQLiteDatabase db = SQLiteDatabase.openDatabase(database.getPath(), null,
                    SQLiteDatabase.OPEN_READONLY | SQLiteDatabase.NO_LOCALIZED_COLLATORS)) {
                db.execSQL("PRAGMA query_only=ON");
                require(db.isReadOnly(), "Database must be opened read-only");
                report.put("sqlite_version", text(db, "SELECT sqlite_version()"));
                String integrity = text(db, "PRAGMA integrity_check");
                require("ok".equals(integrity), "SQLite integrity check: " + integrity);
                report.put("integrity_check", integrity);
                try (Cursor c = db.rawQuery("PRAGMA foreign_key_check", null)) {
                    require(c.getCount() == 0, "Foreign key violations");
                    report.put("foreign_key_violations", c.getCount());
                }
                long orphans = number(db, "SELECT COUNT(*) FROM playlist_tracks pt " +
                    "LEFT JOIN scanned_tracks t ON t.id=pt.track_id " +
                    "LEFT JOIN playlists p ON p.id=pt.playlist_id " +
                    "WHERE t.id IS NULL OR p.id IS NULL");
                require(orphans == 0, "Orphan playlist membership");
                report.put("orphan_playlist_links", orphans);
                long duplicates = number(db, "SELECT COUNT(*) FROM (SELECT file_path," +
                    "is_cue_track,track_number,ROUND(start_time_sec*75),COUNT(*) n " +
                    "FROM scanned_tracks GROUP BY file_path,is_cue_track,track_number," +
                    "ROUND(start_time_sec*75) HAVING n>1)");
                require(duplicates == 0, "Duplicate track identities");
                report.put("duplicate_track_identities", duplicates);
                long invalid = number(db, "SELECT COUNT(*) FROM scanned_tracks WHERE " +
                    "id<=0 OR duration_sec<0 OR start_time_sec<0 OR " +
                    "(is_cue_track=1 AND end_time_sec>0 AND end_time_sec<=start_time_sec)");
                require(invalid == 0, "Invalid IDs or CUE boundaries");
                report.put("invalid_tracks", invalid);
                long maxId = number(db, "SELECT COALESCE(MAX(id),0) FROM scanned_tracks");
                long nextId = number(db, "SELECT CAST(value AS INTEGER) FROM app_settings " +
                    "WHERE key='library_next_track_id'");
                require(nextId > maxId, "Track ID high-water mark is invalid");
                report.put("next_track_id", nextId);
                report.put("tracks", number(db, "SELECT COUNT(*) FROM scanned_tracks"));
                report.put("cue_tracks", number(db, "SELECT COUNT(*) FROM scanned_tracks WHERE is_cue_track=1"));
                report.put("playlists", number(db, "SELECT COUNT(*) FROM playlists"));
                report.put("playlist_links", number(db, "SELECT COUNT(*) FROM playlist_tracks"));
                report.put("app_settings", number(db, "SELECT COUNT(*) FROM app_settings"));
                report.put("dac_settings", number(db, "SELECT COUNT(*) FROM dac_dx1ii_settings"));
                long missing = 0;
                try (Cursor c = db.rawQuery("SELECT DISTINCT file_path FROM scanned_tracks", null)) {
                    while (c.moveToNext()) if (!new File(c.getString(0)).isFile()) missing++;
                }
                require(missing == 0, "Library references missing audio files");
                report.put("missing_audio_files", missing);
            }
            boolean mainUnchanged = before.equals(digest(database));
            // Android SQLite may create an empty WAL when opening a WAL-mode
            // database read-only. No committed frames exist in an empty WAL.
            boolean walUnchanged = beforeWal.equals(digest(wal)) ||
                (beforeWalSize == 0 && wal.length() == 0);
            report.put("main_file_unchanged", mainUnchanged);
            report.put("wal_content_unchanged", walUnchanged);
            require(mainUnchanged && walUnchanged,
                "Database/WAL contents changed during read-only audit");
            report.put("database_and_wal_content_unchanged", true);
            report.put("ok", true);
            result.putString("audit_json", report.toString());
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            try { report.put("ok", false); report.put("error", error.toString()); }
            catch (Exception ignored) {}
            result.putString("audit_json", report.toString());
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}
'''

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.example.hide_player_flutter.database_audit">
  <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="35"/>
  <application android:label="HiFi read-only database audit"/>
  <instrumentation android:name="com.example.hide_player_flutter.database_audit.DatabaseAudit"
    android:targetPackage="com.example.hide_player_flutter"/>
</manifest>'''


def run(args):
    completed = subprocess.run([str(x) for x in args], text=True, capture_output=True)
    if completed.returncode:
        raise RuntimeError(f"Command failed: {args[0]}\n{completed.stdout}\n{completed.stderr}")
    return completed.stdout


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', help='ADB device serial')
    parser.add_argument('--keystore', type=Path,
                        default=Path.home() / '.android/debug.keystore')
    parser.add_argument('--output', type=Path,
                        default=root / 'build/reports/database-audit/vivo.json')
    args = parser.parse_args()
    props = dict(line.split('=', 1) for line in
                 (root / 'android/local.properties').read_text().splitlines() if '=' in line)
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT', props.get('sdk.dir', '')))
    tools = max((sdk / 'build-tools').iterdir(), key=lambda p: tuple(int(n) for n in p.name.split('.')))
    android = sdk / 'platforms/android-35/android.jar'
    javac = shutil.which('javac')
    if not javac or not android.is_file() or not args.keystore.is_file():
        raise RuntimeError('Java, Android API 35 and the app signing keystore are required')
    adb = [str(sdk / 'platform-tools/adb')]
    if args.serial:
        adb += ['-s', args.serial]
    package = 'com.example.hide_player_flutter.database_audit'
    installed = False
    try:
        with tempfile.TemporaryDirectory(prefix='hifi-db-audit-') as temp:
            temp = Path(temp)
            source = temp / 'DatabaseAudit.java'
            source.write_text(JAVA)
            manifest = temp / 'AndroidManifest.xml'
            manifest.write_text(MANIFEST)
            classes = temp / 'classes'
            classes.mkdir()
            run([javac, '-source', '8', '-target', '8', '-classpath', android,
                 '-d', classes, source])
            run([tools / 'd8', '--lib', android, '--min-api', '26', '--output', temp,
                 *classes.rglob('*.class')])
            unsigned = temp / 'audit-unsigned.apk'
            run([tools / 'aapt2', 'link', '-o', unsigned, '--manifest', manifest, '-I', android])
            with zipfile.ZipFile(unsigned, 'a') as apk:
                apk.write(temp / 'classes.dex', 'classes.dex')
            aligned = temp / 'audit-aligned.apk'
            run([tools / 'zipalign', '-f', '4', unsigned, aligned])
            signed = temp / 'audit.apk'
            run([tools / 'apksigner', 'sign', '--ks', args.keystore,
                 '--ks-key-alias', 'androiddebugkey', '--ks-pass', 'pass:android',
                 '--key-pass', 'pass:android', '--out', signed, aligned])
            run([*adb, 'install', '-r', signed])
            installed = True
            output = run([*adb, 'shell', 'am', 'instrument', '-w', '-r',
                          package + '/' + package + '.DatabaseAudit'])
            match = re.search(r'^INSTRUMENTATION_RESULT: audit_json=(.*)$', output, re.MULTILINE)
            if not match:
                raise RuntimeError('No audit result: ' + output)
            report = json.loads(match.group(1))
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
            print(json.dumps(report, ensure_ascii=False, indent=2))
            if not report.get('ok'):
                raise RuntimeError('Database audit failed; see report')
    finally:
        if installed:
            run([*adb, 'uninstall', package])
            run([*adb, 'shell', 'am', 'start', '-n',
                 'com.example.hide_player_flutter/.MainActivity'])


if __name__ == '__main__':
    main()
