abstract class Node {
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]);
}

abstract class View implements Node {
  String get name;
  Component get component;
  ViewType get viewType;
  List<Node> get children;
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

  @override
  final List<Node> children;

  ComponentView(this.component, {this.children = const []});

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

  // TODO: implement children
  @override
  List<Node> get children => [componentView];
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

  // TODO: implement children
  @override
  List<Node> get children => [];
}

abstract class Element implements Node {}

class TextNode implements Node {
  final String value;

  TextNode(this.value);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) =>
      visitor.visitTextElement(this, context);
}

class I18nTextNode implements Node {
  final I18nMessage value;

  I18nTextNode(this.value);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) =>
      visitor.visitI18nTextNode(this, context);
}

class InterpolationNode implements Node {
  final AST expression;

  InterpolationNode(this.expression);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) =>
      visitor.visitInterpolationElement(this, context);
}

// TODO(alorenzen): Copy implementation from angular.
class I18nMessage {}

// TODO(alorenzen): Determine how to represent expressions in new IR.
class AST {
  final String expression;

  AST(this.expression);
}

abstract class IRVisitor<R, C> {
  R visitComponentView(ComponentView componentView, [C context]);
  R visitHostView(HostView hostView, [C context]);
  R visitEmbeddedView(EmbeddedView embeddedView, [C context]);

  R visitTextElement(TextNode textNode, [C context]);
  R visitI18nTextNode(I18nTextNode i18nTextNode, [C context]);
  R visitInterpolationElement(InterpolationNode interpolationNode, [C context]);
}
