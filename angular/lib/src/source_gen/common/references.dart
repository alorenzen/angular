import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
import 'package:code_builder/code_builder.dart';

Reference toBuilder(DartType type, List<ImportElement> imports,
        {bool includeGenerics: true}) =>
    new Reference(type.name, _importFrom(type, imports)).toType().rebuild((b) =>
        b
          ..types.replace(
              includeGenerics ? _coerceTypeArgs(type, imports) : const []));

String _importFrom(DartType dartType, List<ImportElement> imports) {
  final NamespaceBuilder builder = new NamespaceBuilder();
  for (final import in imports) {
    final namespace = builder.createImportNamespaceForDirective(import);
    final exportedElement = import.prefix != null
        ? namespace.getPrefixed(import.prefix.name, dartType.element.name)
        : namespace.get(dartType.element.name);
    if (exportedElement == dartType.element) {
      return import.uri;
    }
  }
  return null;
}

Iterable<Reference> _coerceTypeArgs(
    DartType type, List<ImportElement> imports) {
  if (type is! ParameterizedType) return const [];
  var typeArgs = (type as ParameterizedType).typeArguments;
  if (typeArgs.every((t) => t.isDynamic)) return const [];
  return typeArgs.map((type) => toBuilder(type, imports));
}
