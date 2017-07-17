import 'package:analyzer/dart/ast/ast.dart';
import 'package:barback/barback.dart' show AssetId;

import 'class_matcher_base.dart';

export 'class_matcher_base.dart' show ClassDescriptor;

/// [ClassDescriptor]s for the default angular annotations that can appear
/// on a class. These classes are re-exported in many places so this covers all
/// the possible libraries which could provide them.
const _ENTRYPOINTS = const [
  const ClassDescriptor('AngularEntrypoint', 'package:angular/angular.dart'),
  const ClassDescriptor('AngularEntrypoint', 'package:angular/di.dart'),
  const ClassDescriptor('AngularEntrypoint', 'package:angular/core.dart'),
  const ClassDescriptor(
      'AngularEntrypoint', 'package:angular/platform/browser.dart'),
  const ClassDescriptor(
      'AngularEntrypoint', 'package:angular/platform/worker_app.dart'),
  const ClassDescriptor(
      'AngularEntrypoint', 'package:angular/platform/browser_static.dart'),
  const ClassDescriptor(
      'AngularEntrypoint', 'package:angular/src/core/angular_entrypoint.dart'),
];

/// Checks if a given [Annotation] matches any of the given
/// [ClassDescriptors].
class AnnotationMatcher extends ClassMatcherBase {
  AnnotationMatcher._(List<ClassDescriptor> classDescriptors)
      : super(classDescriptors);

  factory AnnotationMatcher() => new AnnotationMatcher._(_ENTRYPOINTS);

  bool _implementsWithWarning(Annotation annotation, AssetId assetId,
      List<ClassDescriptor> interfaces) {
    ClassDescriptor descriptor = firstMatch(annotation.name, assetId);
    if (descriptor == null) return false;
    return implements(descriptor, interfaces,
        missingSuperClassWarning:
            'Missing `custom_annotation` entry for `${descriptor.superClass}`.');
  }

  /// Checks if an [Annotation] node implements [AngularEntrypoint]
  bool isEntrypoint(Annotation annotation, AssetId assetId) =>
      _implementsWithWarning(annotation, assetId, _ENTRYPOINTS);
}
