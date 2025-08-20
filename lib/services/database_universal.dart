// lib/services/database_universal.dart
export 'database_service.dart'
  if (dart.library.html) 'database_service_web.dart';
