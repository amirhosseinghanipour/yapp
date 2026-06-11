import 'package:record_platform_interface/record_platform_interface.dart';

class RecordLinux extends RecordPlatform {
  static void registerWith() {
    RecordPlatform.instance = RecordLinux();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Audio recording is not supported on Linux in this build.');
}
