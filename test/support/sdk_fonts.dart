import 'dart:io';

import 'package:flutter/services.dart';

const _materialFontsSegments = <String>[
  'bin',
  'cache',
  'artifacts',
  'material_fonts',
];

/// Loads a font from the installed Flutter SDK's material_fonts artifact.
///
/// [candidateNames] must list portable canonical filenames before legacy
/// lowercase aliases. The resolved filename is part of the error when no
/// candidate exists, so a missing or relocated SDK font is diagnosable from
/// the test output alone.
Future<void> loadSdkFont(String family, List<String> candidateNames) async {
  final fontFile = resolveSdkFontFile(family, candidateNames);
  final fontBytes = await fontFile.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
  await loader.load();
}

/// Finds the first existing SDK font from [candidateNames] for [family].
///
/// Canonical SDK filenames such as `Roboto-Regular.ttf` are checked before
/// compatibility aliases such as `roboto-regular.ttf`. The search never
/// depends on current-directory state or on externally installed aliases.
File resolveSdkFontFile(String family, List<String> candidateNames) {
  final candidates = candidateNames
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (candidates.isEmpty) {
    throw ArgumentError.value(
      candidateNames,
      'candidateNames',
      'At least one SDK font filename is required for "$family".',
    );
  }

  final searchRoots = _sdkMaterialFontDirectories();
  final searched = <String>[];
  for (final root in searchRoots) {
    for (final name in candidates) {
      final candidate = File(<String>[root, name].join(Platform.pathSeparator));
      searched.add(candidate.path);
      if (candidate.existsSync()) return candidate.absolute;
    }
  }

  throw StateError(
    'Could not find an SDK font for family "$family". '
    'Candidates: ${candidates.join(', ')}. '
    'Search locations: ${searched.join(', ')}.',
  );
}

List<String> _sdkMaterialFontDirectories() {
  final roots = <String>[];
  void addRoot(String root) {
    final directory = <String>[
      root,
      ..._materialFontsSegments,
    ].join(Platform.pathSeparator);
    if (!roots.contains(directory)) roots.add(directory);
  }

  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    addRoot(directory.path);
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.trim().isNotEmpty) {
    addRoot(flutterRoot.trim());
  }
  return roots;
}
