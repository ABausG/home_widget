import 'package:generator_basics/src/home_widget/interactive_counter.home_widget.dart';

/// Runs in the background when a button of the Interactive Counter widget is
/// tapped, named by `onInteraction` in `home_widget/interactive_counter.dart`.
///
/// The count is read from storage, not from the interaction: the widget may
/// have been tapped again before it rendered the previous change.
Future<void> onInteractiveCounterInteraction(
  InteractiveCounterInteraction interaction,
) async {
  final count = (await InteractiveCounterHomeWidget.getData()).count ?? 0;
  switch (interaction) {
    case InteractiveCounterIncrementInteraction(:final step):
      await InteractiveCounterHomeWidget.saveData(count: count + step);
    case InteractiveCounterDecrementInteraction():
      await InteractiveCounterHomeWidget.saveData(count: count - 1);
  }
  await InteractiveCounterHomeWidget.updateWidget();
}
