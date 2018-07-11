abstract class View {
  String get name;
  Component get component;
  ViewType get viewType;
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]);
}

enum ViewType {
  component,
  host,
  embedded,
}

class ComponentView implements View {
  @override
  final ViewType viewType = ViewType.component;
  @override
  final Component component;

  ComponentView(this.component);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) =>
      visitor.visitComponentView(this, context);

  @override
  String get name => 'View${component.name}';
}

class Component {
  final String name;
  final ChangeDetectionStrategy changeDetectionStrategy;

  Component(this.name, this.changeDetectionStrategy);
}

enum ChangeDetectionStrategy {
  checkAlways,
}

class HostView implements View {
  @override
  final ViewType viewType = ViewType.host;
  @override
  final Component component;

  final ComponentView componentView;

  HostView(this.componentView, this.component);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) =>
      visitor.visitHostView(this, context);

  @override
  String get name => '_View${component.name}Host';
}

class EmbeddedView implements View {
  @override
  final ViewType viewType = ViewType.embedded;
  @override
  final Component component;

  EmbeddedView(this.component);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) {
    return visitor.visitEmbeddedView(this, context);
  }

  // TODO: implement name
  @override
  String get name => null;
}

abstract class IRVisitor<R, C> {
  R visitComponentView(ComponentView componentView, [C context]);
  R visitHostView(HostView hostView, [C context]);
  R visitEmbeddedView(EmbeddedView embeddedView, [C context]);
}
