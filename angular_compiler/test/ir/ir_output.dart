import 'package:angular_compiler/src/ir/model.dart';
import 'package:code_builder/code_builder.dart';

import 'default_ir_visitor.dart';

class OutputIRVisitor extends DefaultIRVisitor<Spec, Null> {
  final ReferenceService _references;

  OutputIRVisitor(this._references);

  @override
  Spec visitComponentView(ComponentView componentView, [Null context]) {
    return new Class((b) => b
      ..name = componentView.name
      ..extend = _appView(componentView.component)
      ..fields.addAll(_fields(componentView))
      ..constructors.add(_componentViewConstructor(componentView))
      ..methods.addAll([
        _build(componentView),
        _detectChangesInternal(componentView),
        _destroyInternal(componentView)
      ]));
  }

  TypeReference _appView(Component component) {
    return new TypeReference((b) => b
      ..symbol = 'AppView'
      ..types.add(_reference(component)));
  }

  @override
  Spec visitHostView(HostView hostView, [Null context]) {
    return new Class((b) => b
      ..name = hostView.name
      ..extend = _appView(hostView.component)
      ..fields.addAll(_fields(hostView))
      ..constructors.add(_hostViewConstructor(hostView))
      ..methods.addAll([
        _build(hostView),
        _detectChangesInternal(hostView),
        _destroyInternal(hostView)
      ]));
  }

  Method _build(View view) {
    return new Method((b) => b
      ..name = 'build'
      ..returns = new TypeReference((b) => b
        ..symbol = 'ComponentRef'
        ..types.add(_reference(view.component)))
      ..body = _visitChildren(view.children, BuildVisitor(_references)));
  }

  Method _destroyInternal(View view) {
    return new Method.returnsVoid((b) => b
      ..name = 'destroyInternal'
      ..body = _visitChildren(view.children, DestroyVisitor(_references)));
  }

  Method _detectChangesInternal(View view) {
    return new Method.returnsVoid((b) => b
      ..name = 'detectChangesInternal'
      ..body =
          _visitChildren(view.children, DetectChangesVisitor(_references)));
  }

  Reference _reference(Component component) => refer(component.name);

  Constructor _componentViewConstructor(ComponentView componentView) =>
      new Constructor((b) => b
        ..requiredParameters.addAll(parentParams)
        ..initializers.add(_appViewConstructor(componentView)));

  Constructor _hostViewConstructor(HostView hostView) =>
      new Constructor((b) => b
        ..requiredParameters.addAll(parentParams)
        ..initializers.add(_appViewConstructor(hostView)));

  static final parentParams = [
    new Parameter((b) => b
      ..name = 'parentView'
      ..type = new TypeReference((b) => b
        ..symbol = 'AppView'
        ..types.add(refer('dynamic')))),
    new Parameter((b) => b
      ..name = 'parentIndex'
      ..type = refer('int'))
  ];

  Code _appViewConstructor(View view) => refer('super').call([
        _viewType(view),
        literalMap({}),
        refer('parentView'),
        refer('parentIndex'),
        _cdStrategy(view),
      ]).code;

  Expression _viewType(View view) {
    return refer('ViewType').property(_property(view.viewType));
  }

  String _property(ViewType viewType) {
    switch (viewType) {
      case ViewType.component:
        return 'component';
      case ViewType.host:
        return 'host';
      case ViewType.embedded:
        return 'embedded';
      default:
        throw new ArgumentError.value(viewType);
    }
  }

  Expression _cdStrategy(View view) => refer('ChangeDetectionStrategy')
      .property(_cdProperty(view.component.changeDetectionStrategy));

  String _cdProperty(ChangeDetectionStrategy changeDetectionStrategy) {
    switch (changeDetectionStrategy) {
      case ChangeDetectionStrategy.checkAlways:
        return 'CheckAlways';
      default:
        throw new ArgumentError.value(changeDetectionStrategy);
    }
  }

  Block _visitChildren(
      List<Node> children, IRVisitor<Code, Null> visitor) {
    final builder = BlockBuilder();
    for (var child in children) {
      var expression = child.accept(visitor);
      if (expression != null) {
        builder.statements.add(expression);
      }
    }
    return builder.build();
  }

  List<Field> _fields(View view) {
    var fields = <Field>[];
    for (var child in view.children) {
      var field = child.accept(FieldVisitor(_references));
      if (field != null) {
        fields.add(field);
      }
    }
    return fields;
  }
}

class FieldVisitor extends DefaultIRVisitor<Field, Null> {
  final ReferenceService _references;

  FieldVisitor(this._references);

  @override
  Field visitComponentView(ComponentView componentView, [Null context]) {
    return Field((b) => b
      ..name = _references.lookup(componentView).symbol
      ..type = refer(componentView.name));
  }

  @override
  Field visitInterpolationElement(InterpolationNode interpolation, [Null context]) {
    return Field((b) => b
        ..name = _references.lookup(interpolation).symbol
        ..type = refer('Text')
    );
  }
}

class BuildVisitor extends DefaultIRVisitor<Code, Null> {
  final ReferenceService _references;

  BuildVisitor(this._references);

  @override
  Code visitComponentView(ComponentView componentView, [Null context]) {
    return _references.lookup(componentView).assign(
        refer(componentView.name).newInstance([refer('this'), literal(0)])).statement;
  }

  @override
  Code visitTextElement(TextNode textElement, [Null context]) {
    return _references
        .lookup(textElement)
        .assign(refer('Text').newInstance([literalString(textElement.value)])).statement;
  }

  @override
  Code visitInterpolationElement(InterpolationNode interpolation, [Null context]) {
    return _references
        .lookup(interpolation)
        .assign(refer('Text').newInstance([literalString('')])).statement;
  }
}

class DetectChangesVisitor extends DefaultIRVisitor<Code, Null> {
  final ReferenceService _references;

  DetectChangesVisitor(this._references);

  @override
  Code visitComponentView(ComponentView componentView, [Null context]) {
    return _references.lookup(componentView).property('detectChanges').call([]).statement;
  }
  
  @override
  Code visitInterpolationElement(InterpolationNode interpolation, [Null context]) {
    var currVal = refer('currVal');
    return Block.of([
      refer('_ctx').property(interpolation.expression.expression).assignFinal(currVal.symbol).statement,
      const Code('if ('),
      lazyCode(() => refer('checkBinding').call([_references.lookup(interpolation), currVal]).code),
      const Code(') {'),
      _references.lookup(interpolation).assign(currVal).statement,
      const Code('}'),
    ]);
  }
}

class DestroyVisitor extends DefaultIRVisitor<Code, Null> {
  final ReferenceService _references;

  DestroyVisitor(this._references);

  @override
  Code visitComponentView(ComponentView componentView, [Null context]) {
    return _references
        .lookup(componentView)
        .nullSafeProperty('destroy')
        .call([]).statement;
  }
}

class ReferenceService {
  final _references = <Node, Reference>{};
  int _counter = 0;

  Reference lookup(Node node) =>
      _references.putIfAbsent(node, () => _createReference(node));

  Reference _createReference(Node node) {
    // TODO: Create names based on node.
    return refer('_foo_${_counter++}');
  }
}
