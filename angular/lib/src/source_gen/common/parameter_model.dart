import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import 'annotation_model.dart';
import 'references.dart' as references;

/// A parameter used in the creation of a reflection type.
class ParameterModel {
  final String paramName;
  final Reference _type;
  final List<Code> _metadata;

  ParameterModel._(
      {this.paramName, Reference type, Iterable<Code> metadata: const []})
      : _type = type,
        _metadata = metadata.toList();

  factory ParameterModel(
      {String paramName,
      String typeName,
      String importedFrom,
      Iterable<String> typeArgs: const [],
      Iterable<String> metadata: const []}) {
    return new ParameterModel._(
        paramName: paramName,
        type: typeName != null
            ? new TypeReference((b) => b
              ..symbol = typeName
              ..url = importedFrom
              ..types.replace(typeArgs.map(_reference)))
            : null,
        metadata: metadata.map(_reference).map(_toCode).toList());
  }

  factory ParameterModel.fromElement(ParameterElement element) {
    return new ParameterModel._(
        paramName: element.name,
        type: references.toBuilder(element.type, element.library.imports,
            includeGenerics: false),
        metadata: _metadataFor(element));
  }

  Code get asList {
    var params = _typeAsList..addAll(_metadata);
    return list(params, type: lib$core.$dynamic, asConst: true);
  }

  List<Code> get _typeAsList => _type != null ? [_toCode(_type)] : [];

  ParameterBuilder get asBuilder => parameter(paramName, _typeAsList);

  static List<Code> _metadataFor(ParameterElement element) {
    final metadata = <Code>[];
    for (ElementAnnotation annotation in element.metadata) {
      metadata.add(_getMetadataInvocation(annotation, element));
    }
    if (element.parameterKind == ParameterKind.POSITIONAL) {
      metadata.add(_toCode(_reference('Optional', optionalPackage)));
    }
    return metadata;
  }

  static Code _getMetadataInvocation(
          ElementAnnotation annotation, Element element) =>
      new AnnotationModel.fromElement(annotation, element).asExpression;
}

const optionalPackage = 'package:angular/src/core/di/decorators.dart';

Reference _reference(String symbol, [String url]) => new Reference(symbol, url);

Code _toCode(Reference reference) => new Code((b) => b
  ..code = '{{TYPE}}'
  ..specs.addAll({'TYPE': () => reference}));
