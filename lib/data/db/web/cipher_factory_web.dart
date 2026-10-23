// ignore_for_file: implementation_imports
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/src/mixin/factory.dart' show buildDatabaseFactory;
import 'package:sqflite_common_ffi/src/method_call.dart' show FfiMethodCall;
import 'package:sqflite_common_ffi/src/sqflite_ffi_impl.dart' show sqfliteFfiHandler;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show SqfliteFfiWebContext, SqfliteFfiWebOptions, sqfliteFfiWebLoadSqlite3Wasm;
import 'package:sqflite_common_ffi_web/src/database_factory_web.dart' show ffiMethodCallHandleNoWebWorker;
import 'package:sqflite_common_ffi_web/src/open_options_check.dart' show checkOpenDatabaseArgumentsWeb;
import 'package:sqflite_common_ffi_web/src/sqflite_ffi_impl_web.dart' show SqfliteFfiHandlerWeb;
import 'package:sqflite_common_ffi_web/src/web/load_sqlite_web.dart' show SqfliteFfiWebContextExt;
import 'package:sqlite3/wasm.dart';

/// `sqflite_common_ffi_web` öffnet Datenbanken mit der Standard-VFS, SQLite3MultipleCiphers verschlüsselt aber
/// nur über die Hüll-VFS `multipleciphers-<Name>` („Encryption is not supported by the VFS“). Dieser Handler
/// öffnet deshalb über die Hüll-VFS der IndexedDB-Ablage; alles andere übernimmt die Bibliothek.
class _CipherHandler extends SqfliteFfiHandlerWeb {
  _CipherHandler(super.context);

  @override
  Future<CommonDatabase> openPlatform(Map<dynamic, dynamic> argumentsMap) async {
    final path = argumentsMap['path'] as String;
    final readOnly = (argumentsMap['readOnly'] as bool?) ?? false;
    final sqlite3 = context.wasmSqlite3!;
    final fs = context.fs!;
    return sqlite3.open(
      path,
      vfs: 'multipleciphers-${fs.name}',
      mode: readOnly ? OpenMode.readOnly : OpenMode.readWriteCreate,
    );
  }
}

/// Datenbankfabrik für den Browser: `sqlite3mc.wasm` im Hauptthread, Dateien in IndexedDB [indexedDbName].
DatabaseFactory createCipherWebFactory({required String wasmPath, required String indexedDbName}) {
  final options = SqfliteFfiWebOptions(sqlite3WasmUri: Uri.parse(wasmPath), indexedDbName: indexedDbName);
  Future<SqfliteFfiWebContext>? loading;
  return buildDatabaseFactory(
    tag: 'ffi_web_cipher',
    invokeMethod: (String method, [Object? arguments]) async {
      if (method == 'openDatabase') checkOpenDatabaseArgumentsWeb(arguments);
      final context = await (loading ??= () async {
        final c = await sqfliteFfiWebLoadSqlite3Wasm(options);
        sqfliteFfiHandler = _CipherHandler(c);
        return c;
      }());
      return ffiMethodCallHandleNoWebWorker(FfiMethodCall(method, arguments), context);
    },
  );
}
