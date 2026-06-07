/// Libraries exported exclusively for use by the `home_widget_cli` package.
///
/// These exports are considered internal implementation details of the
/// `home_widget_generator` and are not subject to semantic versioning
/// guarantees for general public use.
library;

export 'src/parser/widget_tree_parser.dart';
export 'src/parser/widget_value_decoder.dart';
export 'src/utils/inject_glance_modifier.dart';
