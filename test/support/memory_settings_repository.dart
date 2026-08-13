import 'package:setsuna/repositories/settings_repository.dart';

class MemorySettingsRepository extends SettingsRepository {
  MemorySettingsRepository(this.values);

  final Map<String, dynamic> values;
  Map<String, dynamic>? savedValues;

  @override
  Future<SettingsLoadResult> load() async {
    return SettingsLoadResult(
      values: Map<String, dynamic>.from(values),
      credentialsBlocked: false,
    );
  }

  @override
  Future<void> save(
    Map<String, dynamic> values, {
    bool credentialsBlocked = false,
  }) async {
    savedValues = Map<String, dynamic>.from(values);
  }
}
