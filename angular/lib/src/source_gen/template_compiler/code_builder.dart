import 'package:analyzer/dart/ast/ast.dart' hide Directive;
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:code_builder/code_builder.dart';
import 'package:quiver/strings.dart' as strings;
import 'package:angular/src/source_gen/common/namespace_model.dart';
import 'package:angular/src/source_gen/common/ng_deps_model.dart';
import 'package:angular/src/transform/common/names.dart';

import 'template_compiler_outputs.dart';

const _ignoredProblems = const <String>[
  'cancel_subscriptions',
  'constant_identifier_names',
  'non_constant_identifier_names',
  'library_prefixes',
  'UNUSED_IMPORT',
  'UNUSED_SHOWN_NAME',
];

String buildGeneratedCode(
  TemplateCompilerOutputs outputs,
  String sourceFile,
  String libraryName,
) {
  StringBuffer buffer = new StringBuffer();
  // Avoid strong-mode warnings that are not solvable quite yet.
  if (_ignoredProblems.isNotEmpty) {
    var problems = _ignoredProblems.join(',');
    buffer.writeln('// ignore_for_file: $problems');
  }
  if (strings.isNotEmpty(libraryName)) {
    buffer.writeln('library $libraryName$TEMPLATE_EXTENSION;\n');
  }

  String templateCode = outputs.templatesSource?.source ?? '';
  var model = outputs.ngDepsModel;

  var setupMethodMembers = model.createSetupMethod(
      outputs.templatesSource?.deferredModules?.keys?.toSet() ?? new Set());

  var scope = new _NgScope(model);

  _writeImportExports(buffer, sourceFile, model, templateCode, scope,
      outputs.templatesSource?.deferredModules);

  buffer.write(templateCode);

  var library = File.toBuilder();

  if (strings.isNotEmpty(templateCode) && model.reflectables.isNotEmpty) {
    library
        .body.add(model.localMetadataMap as AstBuilder<CompilationUnitMember>);
  }

  library.body.addAll(setupMethodMembers);

  buffer.write(library.accept(new DartEmitter(scope)));
  return buffer.toString();
}

void _writeImportExports(
    StringBuffer buffer,
    String sourceFile,
    NgDepsModel model,
    String templateCode,
    _NgScope scope,
    Map<String, String> deferredModules) {
  // We need to import & export (see below) the source file.
  scope.addPrefixImport(sourceFile, '');
  List<Directive> directives = [new ImportModel(uri: sourceFile).asBuilder];

  if (model.reflectables.isNotEmpty) {
    scope.addPrefixImport(REFLECTOR_IMPORT, REFLECTOR_PREFIX);
    directives.add(new ImportModel(uri: REFLECTOR_IMPORT, prefix: REFLECTOR_PREFIX)
        .asBuilder);
  }

  // TODO(alorenzen): Once templateCompiler uses code_builder, handle this
  // completely in scope.
  for (var import in model.imports) {
    if (import.isDeferred ||
        templateCode.contains(import.asStatement) ||
        (deferredModules != null && deferredModules.containsKey(import.uri))) {
      continue;
    }
    directives.add(import.asBuilder);
  }

  // This is primed with model.depImports, and sets the prefix accordingly.
  directives.addAll(scope.incrementingScope.toImports());

  directives.add(new ExportModel(uri: sourceFile).asBuilder);
  directives.addAll(model.exports.map((model) => model.asBuilder));

  var library = new File((b) => b
  ..directives.addAll(directives));
  buffer.write(library.accept(new DartEmitter(scope)));
}

/// A custom [Scope] which simply delegates to other scopes based on where the
/// import came from.
class _NgScope implements Scope {
  final Map<String, Scope> _delegateScope = {};
  final _PrefixScope _prefixScope = new _PrefixScope();
  final Scope incrementingScope = new Scope();

  _NgScope(NgDepsModel model) {
    for (var import in model.depImports) {
      // Prime cache so that scope.toImports() will return.
      incrementingScope.identifier('', import.uri);
      _delegateScope[import.uri] = incrementingScope;
    }

    for (var import in model.imports) {
      _prefixScope.addImport(import.uri, import.prefix);
      _delegateScope.putIfAbsent(import.uri, () => _prefixScope);
    }
  }

  void addPrefixImport(String uri, String prefix) {
    _prefixScope.addImport(uri, prefix);
    _delegateScope[uri] = _prefixScope;
  }

  @override
  Identifier identifier(String name, [String importFrom]) {
    if (importFrom == null) {
      return Scope.identity.identifier(name, importFrom);
    }
    var scope = _delegateScope.putIfAbsent(importFrom, () => Scope.identity);
    return scope.identifier(name, importFrom);
  }

  // For now, we handle imports separately from the rest of the generated code.
  // Otherwise, we would add the import statements after the output from the
  // template compiler.
  @override
  List<ImportBuilder> toImports() => const [];
}

/// A [Scope] which uses a prefix if one has already been set, otherwise none.
class _PrefixScope implements Scope {
  final Map<String, String> _prefixes = {};

  void addImport(String uri, String prefix) {
    if (prefix != null) {
      _prefixes[uri] = prefix;
    }
  }

  @override
  Identifier identifier(String name, [String importFrom]) {
    if (importFrom == null || !_prefixes.containsKey(importFrom)) {
      return Scope.identity.identifier(name, importFrom);
    }
    var prefix = _prefixes[importFrom];
    return astFactory.prefixedIdentifier(
      Scope.identity.identifier(prefix, null),
      $period,
      Scope.identity.identifier(name, null),
    );
  }

  @override
  List<ImportBuilder> toImports() => const [];
}
