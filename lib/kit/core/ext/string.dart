import 'package:url_launcher/url_launcher_string.dart';

extension StringX on String {
  Future<bool> launchUrl() async {
    return await launchUrlString(this);
  }
}
