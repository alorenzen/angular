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
}
