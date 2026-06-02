import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initializeDatabaseImpl() async {
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
