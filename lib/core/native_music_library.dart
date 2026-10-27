import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

/// One C++ library owns CUE scanning, metadata and every SQLite connection.
class NativeMusicLibrary {
  static String? testingLibraryPath;
  static NativeMusicLibrary? _instance;
  static NativeMusicLibrary get instance => _instance ??= NativeMusicLibrary._();
  late final DynamicLibrary _library;
  String? _libraryPath;
  late final NativeFinalizer _databaseFinalizer;

  NativeMusicLibrary._({String? libraryPath}) {
    final override = libraryPath ?? testingLibraryPath ??
        Platform.environment['HIFI_LIBRARY_TEST_DYLIB'];
    if (override != null && override.isNotEmpty) {
      _libraryPath = override;
      _library = DynamicLibrary.open(override);
    } else if (Platform.isIOS) {
      _library = DynamicLibrary.process();
    } else {
      final executable = File(Platform.resolvedExecutable).parent;
      final candidates = Platform.isAndroid
          ? ['libhifi_audio_ffi.so']
          : Platform.isMacOS
              ? [
                  '${executable.parent.path}/Frameworks/libhifi_audio_ffi.dylib',
                  '${executable.path}/libhifi_audio_ffi.dylib',
                  'native/build/libhifi_audio_ffi.dylib',
                ]
              : Platform.isWindows
                  ? ['${executable.path}/hifi_audio_ffi.dll']
                  : ['${executable.path}/lib/libhifi_audio_ffi.so',
                     '${executable.path}/libhifi_audio_ffi.so', 'libhifi_audio_ffi.so'];
      Object? lastError;
      DynamicLibrary? loaded;
      for (final path in candidates) {
        try {
          final candidate = DynamicLibrary.open(path);
          if (!candidate.providesSymbol('hifi_library_scan_json')) {
            throw StateError('audio_engine does not include the shared library core');
          }
          loaded = candidate;
          _libraryPath = path;
          break;
        } catch (error) { lastError = error; }
      }
      if (loaded == null) throw StateError('Cannot load music library engine: $lastError');
      _library = loaded;
    }
    _databaseFinalizer = NativeFinalizer(_library.lookup<NativeFunction<Void Function(Pointer<Void>)>>('hifi_library_db_close'));
    if (!_library.providesSymbol('hifi_library_scan_json')) {
      throw StateError('Update the locked audio_engine: shared library ABI is missing');
    }
  }

  static Map<String, dynamic> _decode(Pointer<Utf8> value) {
    final result = jsonDecode(value.toDartString()) as Map<String, dynamic>;
    if (result['ok'] == false) throw StateError(result['error'] as String? ?? 'Native library operation failed');
    return result;
  }

  static Database openDatabase(String path) => instance._openDatabase(path);
  Database _openDatabase(String path) {
    final nativePath = path.toNativeUtf8();
    try {
      final handle = _library.lookupFunction<Pointer<Void> Function(Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Utf8>)>('hifi_library_db_open')(nativePath);
      if (handle == nullptr) {
        _query(handle, '', const []); // returns the engine's actual open error
        throw StateError('Cannot open native library database');
      }
      return Database._(this, handle);
    } finally { calloc.free(nativePath); }
  }

  List<Map<String, dynamic>> _query(Pointer<Void> handle, String sql, List<Object?> parameters) {
    final nativeSql = sql.toNativeUtf8();
    final nativeParameters = jsonEncode(parameters).toNativeUtf8();
    try {
      final result = _library.lookupFunction<
          Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)>(
          'hifi_library_db_query_json')(handle, nativeSql, nativeParameters);
      return (_decode(result)['rows'] as List).cast<Map<String, dynamic>>();
    } finally { calloc.free(nativeSql); calloc.free(nativeParameters); }
  }

  static Map<String, dynamic> metadata(String path) {
    final nativePath = path.toNativeUtf8();
    try {
      final result = instance._library.lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)>('hifi_library_metadata_json')(nativePath);
      return _decode(result);
    } finally { calloc.free(nativePath); }
  }

  static Future<Map<String, dynamic>> scan({required String database,
      required List<String> roots, String documents = '', bool partial = false,
      bool global = false}) {
    final path = instance._libraryPath;
    // Only send strings and flags to the worker. Database handles and FFI
    // pointers remain in the isolate that owns them.
    return Isolate.run(() => NativeMusicLibrary._(libraryPath: path)
        ._scan(database, roots, documents, (partial ? 1 : 0) | (global ? 2 : 0)));
  }
  Map<String, dynamic> _scan(String database, List<String> roots, String documents, int flags) {
    final nativeDatabase = database.toNativeUtf8();
    final nativeDocuments = documents.toNativeUtf8();
    final nativeRoots = calloc<Pointer<Utf8>>(roots.length);
    for (var i = 0; i < roots.length; i++) { nativeRoots[i] = roots[i].toNativeUtf8(); }
    try {
      return _decode(_library.lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>, Uint32, Pointer<Utf8>, Uint32),
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>, int, Pointer<Utf8>, int)>(
          'hifi_library_scan_json')(nativeDatabase, nativeRoots, roots.length, nativeDocuments, flags));
    } finally {
      for (var i = 0; i < roots.length; i++) { calloc.free(nativeRoots[i]); }
      calloc.free(nativeRoots); calloc.free(nativeDatabase); calloc.free(nativeDocuments);
    }
  }
}

typedef ResultSet = List<Map<String, dynamic>>;
class Database implements Finalizable {
  Database._(this._engine, this._handle) {
    _engine._databaseFinalizer.attach(this, _handle, detach: this);
  }
  final NativeMusicLibrary _engine;
  Pointer<Void> _handle;
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    if (_handle == nullptr) throw StateError('Database is closed');
    return _engine._query(_handle, sql, parameters);
  }
  void execute(String sql, [List<Object?> parameters = const []]) { select(sql, parameters); }
  NativeStatement prepare(String sql) => NativeStatement._(this, sql);
  void close() {
    if (_handle == nullptr) return;
    _engine._databaseFinalizer.detach(this);
    _engine._library.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'hifi_library_db_close')(_handle);
    _handle = nullptr;
  }
  void dispose() => close();
}
class NativeStatement {
  NativeStatement._(this._database, this._sql);
  final Database _database;
  final String _sql;
  bool _closed = false;
  ResultSet select([List<Object?> parameters = const []]) {
    if (_closed) throw StateError('Statement is closed');
    return _database.select(_sql, parameters);
  }
  void execute([List<Object?> parameters = const []]) { select(parameters); }
  void close() { _closed = true; }
  void dispose() => close();
}
