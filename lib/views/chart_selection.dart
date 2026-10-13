import 'package:flutter/foundation.dart';

/// Presentation state shared by Overview, Spectrum and its focused route.
class ChartSelection extends ChangeNotifier {
  bool timeGraph = false;
  final Map<String, bool> _restored = {};
  String? _solo;

  bool get canReset => _restored.isNotEmpty || _solo != null;
  String? solo(Set<String> visible) => visible.contains(_solo) ? _solo : null;
  Set<String> hidden(Set<String> visible) => {
    for (final id in visible)
      if (solo(visible) != null ? id != _solo : _restored[id] == false) id,
  };
  String nextAction(String id, Set<String> visible) => solo(visible) == id
      ? 'Show all networks'
      : solo(visible) != null || _restored[id] == true
      ? 'Show only this network'
      : _restored[id] == false
      ? 'Include this network'
      : 'Exclude this network';

  void toggleGraph() {
    timeGraph = !timeGraph;
    notifyListeners();
  }

  void cycle(String id, Set<String> visible, Set<String> current) {
    _restored.removeWhere((id, _) => !current.contains(id));
    if (!visible.contains(_solo)) _solo = null;
    if (_solo == id) {
      reset();
      return;
    }
    if (_solo != null || _restored[id] == true) {
      _solo = id;
    } else {
      _restored[id] = _restored[id] == false;
    }
    notifyListeners();
  }

  void reset() {
    _restored.clear();
    _solo = null;
    notifyListeners();
  }
}
