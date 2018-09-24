import 'package:angular_compiler/src/ir/model.dart';

class DefaultIRVisitor<R, C> implements IRVisitor<R, C> {
  @override
  R visitComponentView(ComponentView componentView, [C context]) => null;

  @override
  R visitEmbeddedView(EmbeddedView embeddedView, [C context]) => null;

  @override
  R visitHostView(HostView hostView, [C context]) => null;

  @override
  R visitTextElement(TextNode textElement, [C context]) => null;

  @override
  R visitInterpolationElement(InterpolationNode interpolationElement,
          [C context]) =>
      null;

  @override
  R visitI18nTextNode(I18nTextNode i18nTextNode, [C context]) => null;

  @override
  R visitHtmlElement(HtmlElement htmlElement, [C context]) => null;

  @override
  R visitAttribute(Attribute attribute, [C context]) => null;

  List<T> visitAll<T extends R>(Iterable<Node> nodes, [C context]) {
    final results = <T>[];
    for (var node in nodes) {
      var result = node.accept(this, context);
      if (result != null) results.add(result);
    }
    return results;
  }
}
