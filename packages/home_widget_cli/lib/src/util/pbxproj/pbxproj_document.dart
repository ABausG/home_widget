import 'pbxproj_parser.dart';

export 'pbxproj_parser.dart';

/// An object of a pbxproj's top-level `objects` dictionary.
final class PbxObject {
  /// Creates the object stored under [id] by [entry].
  const PbxObject(this.id, this.entry);

  /// The key the object is stored under. Xcode writes 24 hex digits, but any
  /// string is a valid id.
  final String id;

  /// The `id = { … };` entry holding the object.
  final PbxDictEntry entry;

  /// The object's fields.
  PbxDict get fields => entry.value as PbxDict;

  /// The object's class.
  String? get isa => fields.string('isa');

  /// The string field [name].
  String? string(String name) => fields.string(name);

  /// The string elements of the array field [name], empty when there is none.
  List<String> strings(String name) => fields.array(name)?.strings ?? const [];
}

/// A `/* Begin <isa> section */ … /* End <isa> section */` pair.
final class PbxSection {
  /// Creates a section named [isa].
  const PbxSection(this.isa, this.begin, this.end);

  /// The class of the objects the section groups.
  final String isa;

  /// The opening marker.
  final PbxComment begin;

  /// The closing marker, or null when the file never closes the section.
  final PbxComment? end;
}

/// A parsed `project.pbxproj`, indexed for the lookups the patcher makes.
final class Pbxproj {
  Pbxproj._(this.text, this.root, this.objectsDict, this.comments)
      : objects = {
          for (final entry in objectsDict.entries)
            if (entry.value is PbxDict)
              entry.key.value: PbxObject(entry.key.value, entry),
        };

  /// Parses [text], throwing a [FormatException] when it is not a property
  /// list or has no `objects` dictionary.
  factory Pbxproj.parse(String text) {
    final result = parsePbxPlist(text);
    final objects = result.root.dict('objects');
    if (objects == null) {
      throw const FormatException(
        'The project has no top-level "objects" dictionary',
      );
    }
    return Pbxproj._(text, result.root, objects, result.comments);
  }

  /// The source the nodes point into.
  final String text;

  /// The top-level dictionary.
  final PbxDict root;

  /// The top-level `objects` dictionary.
  final PbxDict objectsDict;

  /// Every object by id, in source order.
  final Map<String, PbxObject> objects;

  /// Every `/* … */` comment, in source order.
  final List<PbxComment> comments;

  /// The object stored under [id].
  PbxObject? object(String? id) => id == null ? null : objects[id];

  /// The object stored under [id] when it is of class [isa].
  PbxObject? objectOfIsa(String? id, String isa) {
    final object = this.object(id);
    return object?.isa == isa ? object : null;
  }

  /// The objects of class [isa], in source order.
  Iterable<PbxObject> objectsOfIsa(String isa) =>
      objects.values.where((object) => object.isa == isa);

  /// The `PBXProject` the file describes: the one `rootObject` names, or the
  /// only one there is when the file does not say.
  PbxObject? get rootProject {
    final named = object(root.string('rootObject'));
    if (named != null) return named.isa == 'PBXProject' ? named : null;
    final projects = objectsOfIsa('PBXProject').toList();
    return projects.length == 1 ? projects.single : null;
  }

  /// The `PBXNativeTarget` whose `name` field is [name].
  PbxObject? nativeTargetNamed(String name) {
    for (final target in objectsOfIsa('PBXNativeTarget')) {
      if (target.string('name') == name) return target;
    }
    return null;
  }

  /// The build configurations the `buildConfigurationList` of [owner] lists,
  /// in list order.
  List<PbxObject> buildConfigurationsOf(PbxObject owner) =>
      configurationsInList(owner.string('buildConfigurationList'));

  /// The build configurations the `XCConfigurationList` [listId] lists, in
  /// list order.
  List<PbxObject> configurationsInList(String? listId) => [
        for (final id in object(listId)?.strings('buildConfigurations') ??
            const <String>[])
          if (objectOfIsa(id, 'XCBuildConfiguration') case final config?)
            config,
      ];

  /// [target]'s build phases of class [isa], in build order.
  List<PbxObject> buildPhasesOf(PbxObject target, String isa) => [
        for (final id in target.strings('buildPhases'))
          if (objectOfIsa(id, isa) case final phase?) phase,
      ];

  /// The section markers inside `objects`, in source order.
  List<PbxSection> get sections {
    final markers = RegExp(r'^(Begin|End) (\w+) section$');
    final open = <String>{};
    final sections = <PbxSection>[];
    for (final comment in comments) {
      if (comment.start < objectsDict.start || comment.end > objectsDict.end) {
        continue;
      }
      final match = markers.firstMatch(comment.text);
      if (match == null) continue;
      final isa = match.group(2)!;
      if (match.group(1) == 'Begin') {
        open.add(isa);
        sections.add(PbxSection(isa, comment, null));
      } else if (open.remove(isa)) {
        final index = sections.lastIndexWhere((s) => s.isa == isa);
        sections[index] = PbxSection(isa, sections[index].begin, comment);
      }
    }
    return sections;
  }

  /// Every node in the file in source order, dictionary keys included.
  Iterable<PbxNode> get nodes sync* {
    Iterable<PbxNode> walk(PbxNode node) sync* {
      yield node;
      switch (node) {
        case PbxArray(:final items):
          for (final item in items) {
            yield* walk(item.value);
          }
        case PbxDict(:final entries):
          for (final entry in entries) {
            yield entry.key;
            yield* walk(entry.value);
          }
        case PbxString() || PbxData():
          break;
      }
    }

    yield* walk(root);
  }
}

/// The build settings [configuration] spells out itself, by name.
///
/// A list value stands for its elements joined by spaces, which is how Xcode
/// reads it. Conditional settings (`KEY[sdk=iphoneos*]`) are left out: they
/// apply to a subset of builds only.
Map<String, String> ownBuildSettings(PbxObject configuration) {
  final settings = configuration.fields.dict('buildSettings');
  if (settings == null) return const {};
  return {
    for (final entry in settings.entries)
      if (!entry.key.value.contains('['))
        if (buildSettingValue(entry) case final value?) entry.key.value: value,
  };
}

/// The value of one `buildSettings` entry, a list joined by spaces.
String? buildSettingValue(PbxDictEntry entry) => switch (entry.value) {
      PbxString(:final value) => value,
      PbxArray(:final strings) => strings.join(' '),
      _ => null,
    };
