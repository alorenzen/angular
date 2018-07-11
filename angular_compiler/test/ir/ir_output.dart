import 'package:angular_compiler/src/ir/model.dart';
import 'package:code_builder/code_builder.dart';

class OutputIRVisitor implements IRVisitor<Spec, Null> {
  @override
  Spec visitComponentView(ComponentView componentView, [Null context]) {
    return new Class((b) => b
      ..name = componentView.name
      ..extend = _appView(componentView.component)
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
  Spec visitEmbeddedView(EmbeddedView embeddedView, [Null context]) {
    return null;
  }

  @override
  Spec visitHostView(HostView hostView, [Null context]) {
    return new Class((b) => b
      ..name = hostView.name
      ..extend = _appView(hostView.component)
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
        ..types.add(_reference(view.component))));
  }

  Method _destroyInternal(View view) {
    return new Method.returnsVoid((b) => b
      ..name = 'destroyInternal'
      ..body =
          refer('_compView').nullSafeProperty('destroy').call([]).statement);
  }

  Method _detectChangesInternal(View view) {
    return new Method.returnsVoid((b) => b..name = 'detectChangesInternal');
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
}
