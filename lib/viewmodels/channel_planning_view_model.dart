import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/channel_plan.dart';
import '../views/analyser_providers.dart';
import 'analyser_view_model.dart';

final planningAssumptionsProvider =
    NotifierProvider<
      ChannelPlanningViewModel,
      Map<WifiBand, PlanningAssumptions>
    >(ChannelPlanningViewModel.new);

class ChannelPlanningViewModel
    extends Notifier<Map<WifiBand, PlanningAssumptions>> {
  @override
  Map<WifiBand, PlanningAssumptions> build() => const {};

  void apply(WifiBand band, int width, String shortlist) {
    final channels = parsePlanningChannels(shortlist, band, width);
    if (!planningWidths(band).contains(width)) {
      throw const FormatException('Choose a supported width.');
    }
    state = Map.unmodifiable({
      ...state,
      band: PlanningAssumptions(width: width, channels: channels),
    });
  }

  void reset(WifiBand band) {
    state = Map.unmodifiable({...state}..remove(band));
  }
}

final selectedPlanningAssumptionsProvider = Provider<PlanningAssumptions>((
  ref,
) {
  final band = ref.watch(analyserProvider.select((s) => s.band));
  return ref.watch(planningAssumptionsProvider.select((s) => s[band])) ??
      PlanningAssumptions();
});

final channelPlansProvider = Provider<List<ChannelPlan>>((ref) {
  final aps = ref.watch(accessPointsProvider);
  final (band, exclude) = ref.watch(
    analyserProvider.select((s) => (s.band, s.excludeConnected)),
  );
  final assumptions = ref.watch(selectedPlanningAssumptionsProvider);
  return planChannels(aps, band, assumptions, excludeConnected: exclude);
});
