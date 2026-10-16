import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportRepository {
  static final page = Uri.https('buymeacoffee.com', '/samirpandey');

  Future<bool> openPage() =>
      launchUrl(page, mode: LaunchMode.externalApplication);
}

final supportRepositoryProvider = Provider((ref) => SupportRepository());
