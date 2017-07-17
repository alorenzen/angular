import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import 'references.dart';

/// An annotation on a reflection type.
class AnnotationModel {
  final String name;
  final Reference type;
  final bool _isConstObject;
  final Iterable<Reference> _parameters;
  final Iterable<Parameter> _namedParameters;

  AnnotationModel(
      {this.name,
      Reference type,
      bool isConstObject: false,
      Iterable<Reference> parameters: const [],
      Iterable<Parameter> namedParameters: const []})
      : this.type = type ?? new Reference(name),
        _isConstObject = isConstObject,
        _parameters = parameters,
        _namedParameters = namedParameters;

  factory AnnotationModel.fromElement(
    // Not part of public API yet: https://github.com/dart-lang/sdk/issues/28631
    ElementAnnotationImpl annotation,
    Element hostElement,
  ) {
    var element = annotation.element;
    if (element is ConstructorElement) {
      var parameters = <Reference>[];
      var namedParameters = <Parameter>[];
      for (var arg in annotation.annotationAst.arguments.arguments) {
        if (arg is NamedExpression) {
          namedParameters.add(
            new Parameter((b) => b
              ..named = true
              ..name = arg.name.label.name
              ..defaultTo =
                  new Code((b) => b..code = arg.expression.toSource())),
          );
        } else {
          parameters.add(
            new ExpressionBuilder.raw((_) => arg.toSource()),
          );
        }
      }
      return new AnnotationModel(
        name: element.enclosingElement.name,
        type: toBuilder(element.type.returnType, hostElement.library.imports),
        isConstObject: false,
        parameters: parameters,
        namedParameters: namedParameters,
      );
    } else {
      // TODO(alorenzen): Determine if prefixing element.name is necessary.
      return new AnnotationModel(name: element.name, isConstObject: true);
    }
  }

  Code get asExpression =>
      new Code((b) => b..code = _asCode ..specs.addAll({'TYPE': () => type}));

  String get _asCode =>
      _isConstObject
      ? '{{TYPE}}'
      : 'const {{TYPE}}${(_parameters, namedArguments: _namedParametersAsMap)}';



  Map<String, ExpressionBuilder> get _namedParametersAsMap =>
      new Map.fromIterable(_namedParameters,
          key: (param) => param.name, value: (param) => param.value);
}
