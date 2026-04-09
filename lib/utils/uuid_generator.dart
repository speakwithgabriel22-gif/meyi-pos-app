import 'package:uuid/uuid.dart';

class UuidGenerator {
  static const _uuid = Uuid();
  
  /// Genera un UUID v4
  static String generate() => _uuid.v4();
}
