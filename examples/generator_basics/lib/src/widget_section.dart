import 'package:flutter/material.dart';

/// A collapsible section for a single generated widget.
///
/// The collapsed row reports whether the widget is currently placed on a home
/// screen; the expanded body offers the launcher pin dialog (where the platform
/// supports it) followed by the widget's own controls.
class WidgetSection extends StatefulWidget {
  const WidgetSection({
    super.key,
    required this.title,
    required this.isInstalled,
    required this.isRequestPinWidgetSupported,
    required this.requestPinWidget,
    this.description,
    this.children = const [],
  });

  final String title;
  final String? description;

  /// `<Name>HomeWidget.isInstalled` — true once at least one instance of this
  /// widget sits on a home screen.
  final Future<bool> Function() isInstalled;

  /// `<Name>HomeWidget.isRequestPinWidgetSupported` — Android 8+ with a
  /// launcher that implements pinning; always false on iOS.
  final Future<bool> Function() isRequestPinWidgetSupported;

  /// `<Name>HomeWidget.requestPinWidget` — opens the launcher's pin dialog.
  final Future<void> Function() requestPinWidget;

  final List<Widget> children;

  @override
  State<WidgetSection> createState() => _WidgetSectionState();
}

class _WidgetSectionState extends State<WidgetSection>
    with WidgetsBindingObserver {
  bool? _installed;
  bool _canPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pinning happens in the launcher, outside the app, so the install state
    // can have changed while the app was in the background.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final installed = await _guard(widget.isInstalled);
    final canPin = await _guard(widget.isRequestPinWidgetSupported);
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _canPin = canPin;
    });
  }

  Future<void> _pin() {
    return _guard(() async {
      await widget.requestPinWidget();
      return true;
    });
  }

  static Future<bool> _guard(Future<bool> Function() call) async {
    try {
      return await call();
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final installed = _installed;

    final (IconData icon, Color color, String label) = switch (installed) {
      null => (Icons.hourglass_empty, colors.outline, 'Checking…'),
      true => (
        Icons.check_circle,
        colors.primary,
        'Installed on the home screen',
      ),
      false => (
        Icons.radio_button_unchecked,
        colors.outline,
        'Not on the home screen',
      ),
    };

    return ExpansionTile(
      title: Text(widget.title),
      leading: Icon(icon, size: 20, color: color),
      subtitle: Text(label, style: theme.textTheme.bodySmall),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      onExpansionChanged: (expanded) {
        if (expanded) _refresh();
      },
      children: [
        if (widget.description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.description!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        if (_canPin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _pin,
                icon: const Icon(Icons.add_to_home_screen),
                label: const Text('Add to home screen'),
              ),
            ),
          ),
        ...widget.children,
      ],
    );
  }
}
