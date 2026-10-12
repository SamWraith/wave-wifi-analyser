import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingRepository {
  Future<bool> isComplete();
  Future<void> complete();
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => LocalOnboardingRepository(),
);

class LocalOnboardingRepository implements OnboardingRepository {
  static const completionKey = 'onboardingComplete';

  @override
  Future<bool> isComplete() async =>
      (await SharedPreferences.getInstance()).getBool(completionKey) ?? false;

  @override
  Future<void> complete() async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      completionKey,
      true,
    )) {
      throw StateError('Could not save onboarding completion');
    }
  }
}
