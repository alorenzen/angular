import 'package:meta/meta.dart';

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

/// An internationalized message.
class I18nMessage {
  /// The message text to be translated for different locales.
  final String text;

  /// A description of a message's use.
  ///
  /// This provides translators more context to aid with translation.
  final String description;

  /// Arguments that appear as interpolations in [text].
  ///
  /// These are currently only used to support HTML nested within this message.
  final Map<String, String> args;

  /// The meaning of a message, used to disambiguate equivalent messages.
  ///
  /// It's possible that two messages are textually equivalent in the source
  /// language, but have different meanings. In this case it's important that
  /// they are handled as separate translations.
  ///
  /// This value is optional, and may be null if omitted.
  final String meaning;

  /// Whether this message should be skipped for internationalization.
  ///
  /// When true, this message is still be validated and rendered, but it isn't
  /// extracted for translation. This is useful for placeholder messages during
  /// development that haven't yet been finalized.
  final bool skip;

  I18nMessage({
    @required this.text,
    @required this.description,
    this.args = const {},
    this.meaning,
    this.skip = false,
  });
}

abstract class Element implements Node {}

class HtmlElement implements Element {
  final String tagName;
  final List<Attribute> attributes;

  final List<Node> children;

  HtmlElement(this.tagName,
      {this.attributes = const [], this.children = const []});

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) =>
      visitor.visitHtmlElement(this, context);
}

class Attribute implements Node {
  final String name;
  final AttributeValue value;

  Attribute(this.name, this.value);

  @override
  R accept<R, C>(IRVisitor<R, C> visitor, [C context]) {
    return visitor.visitAttribute(this, context);
  }
}

abstract class AttributeValue<T> {
  T get value;
}

class LiteralAttributeValue implements AttributeValue<String> {
  @override
  final String value;

  LiteralAttributeValue(this.value);
}

class I18nAttributeValue implements AttributeValue<I18nMessage> {
  @override
  final I18nMessage value;

  I18nAttributeValue(this.value);
}

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
  R visitHtmlElement(HtmlElement htmlElement, [C context]);
  R visitAttribute(Attribute attribute, [C context]);
}
