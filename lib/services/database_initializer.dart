import 'database_initializer_stub.dart'
    if (dart.library.io) 'database_initializer_io.dart';

Future<void> initializeDatabase() => initializeDatabaseImpl();
