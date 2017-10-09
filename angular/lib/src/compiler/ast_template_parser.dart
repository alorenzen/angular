import 'package:angular_ast/angular_ast.dart' as ast;
import 'package:source_span/source_span.dart';

import 'compile_metadata.dart';
import 'expression_parser/ast.dart';
import 'expression_parser/parser.dart';
import 'identifiers.dart';
import 'schema/element_schema_registry.dart';
import 'selector.dart';
import 'style_url_resolver.dart';
import 'template_ast.dart' as ng;
import 'template_parser.dart';
import 'template_preparser.dart';

/// A [TemplateParser] which uses the `angular_ast` package to parse angular
/// templates.
class AstTemplateParser implements TemplateParser {
  @override
  final ElementSchemaRegistry schemaRegistry;

  final Parser parser;

  AstTemplateParser(this.schemaRegistry, this.parser);

  @override
  List<ng.TemplateAst> parse(
      CompileDirectiveMetadata compMeta,
      String template,
      List<CompileDirectiveMetadata> directives,
      List<CompilePipeMetadata> pipes,
      String name) {
    final parsedAst = ast.parse(template,
        // TODO(alorenzen): Use real sourceUrl.
        sourceUrl: '/test#inline',
        desugar: true,
        toolFriendlyAst: true,
        parseExpressions: false);
    // TODO(alorenzen): Remove once all tests are passing.
    parsedAst.forEach(print);
    final filter = new ElementFilter();
    final filteredAst = filter.visitAll(parsedAst);
    final visitor = new Visitor(parser, schemaRegistry);
    final context = new ParseContext(directives: directives);
    return filteredAst
        .map((templateAst) => templateAst.accept(visitor, context))
        .toList();
  }
}

class Visitor implements ast.TemplateAstVisitor<ng.TemplateAst, ParseContext> {
  final Parser parser;
  final ElementSchemaRegistry schemaRegistry;

  int ngContentIndex = 0;

  Visitor(this.parser, this.schemaRegistry);

  @override
  ng.TemplateAst visitElement(ast.ElementAst astNode, [ParseContext context]) {
    var matchedDirectives = _matchElementDirectives(context, astNode);
    var directiveAsts = _toAst(matchedDirectives, astNode.sourceSpan,
        astNode.name, _location(astNode));
    final elementContext =
    context.withElementName(astNode.name).bindDirectives(directiveAsts);
    return new ng.ElementAst(
        astNode.name,
        _visitAll(astNode.attributes, elementContext),
        _visitAll(astNode.properties, elementContext),
        _visitAll(astNode.events, elementContext),
        _visitAll(astNode.references, elementContext),
        directiveAsts,
        [] /* providers */,
        null /* elementProviderUsage */,
        _visitAll(astNode.childNodes, elementContext),
        _findNgContentIndexForElement(astNode, context),
        astNode.sourceSpan);
  }

  int _findNgContentIndexForElement(ast.ElementAst astNode,
      ParseContext context) {
    return context
        .findNgContentIndex(_projectAs(astNode) ?? _elementSelector(astNode));
  }

  _projectAs(ast.ElementAst astNode) {
    for (var attr in astNode.attributes) {
      if (attr.name == NG_PROJECT_AS) {
        return CssSelector.parse(attr.value)[0];
      }
    }
    return null;
  }

  @override
  ng.TemplateAst visitEmbeddedTemplate(ast.EmbeddedTemplateAst astNode,
      [ParseContext context]) {
    var matchedDirectives = _matchTemplateDirectives(context, astNode);
    var directiveAsts = _toAst(matchedDirectives, astNode.sourceSpan,
        TEMPLATE_ELEMENT, _location(astNode));
    final embeddedContext = context.forTemplate().bindDirectives(directiveAsts);
    _visitAll(astNode.properties, embeddedContext);
    return new ng.EmbeddedTemplateAst(
        _visitAll(astNode.attributes, embeddedContext),
        _visitAll(astNode.events, embeddedContext),
        _visitAll(astNode.references, embeddedContext),
        _visitAll(astNode.letBindings, embeddedContext),
        directiveAsts,
        [] /* providers */,
        null /* elementProviderUsage */,
        _visitAll(astNode.childNodes, embeddedContext),
        _findNgContentIndexForTemplate(astNode, context),
        astNode.sourceSpan);
  }

  int _findNgContentIndexForTemplate(ast.EmbeddedTemplateAst astNode,
      ParseContext context) {
    return context.findNgContentIndex(
        _templateProjectAs(astNode) ?? _templateSelector(astNode));
  }

  _templateProjectAs(ast.EmbeddedTemplateAst astNode) {
    for (var attr in astNode.attributes) {
      if (attr.name == NG_PROJECT_AS) {
        return CssSelector.parse(attr.value)[0];
      }
    }
    return null;
  }

  @override
  ng.TemplateAst visitEmbeddedContent(ast.EmbeddedContentAst astNode,
      [ParseContext context]) =>
      // TODO(alorenzen): Support ngProjectAs.
  new ng.NgContentAst(
      ngContentIndex++,
      context.findNgContentIndex(CssSelector.parse(astNode.selector)[0]),
      astNode.sourceSpan);

  @override
  ng.TemplateAst visitAttribute(ast.AttributeAst astNode,
      [ParseContext context]) {
    if (astNode.name == NG_PROJECT_AS) return null;
    _bindLiteralToDirectives(context, astNode);
    return new ng.AttrAst(
        astNode.name, astNode.value ?? '', astNode.sourceSpan);
  }

  @override
  ng.TemplateAst visitEvent(ast.EventAst astNode, [ParseContext _]) {
    var value = parser.parseAction(astNode.value, _location(astNode), const []);
    return new ng.BoundEventAst(astNode.name, value, astNode.sourceSpan);
  }

  @override
  ng.TemplateAst visitInterpolation(ast.InterpolationAst astNode,
      [ParseContext context]) {
    var element = parser
        .parseInterpolation('{{${astNode.value}}}', _location(astNode), []);
    return new ng.BoundTextAst(element,
        context.findNgContentIndex(TEXT_CSS_SELECTOR), astNode.sourceSpan);
  }

  @override
  ng.TemplateAst visitLetBinding(ast.LetBindingAst astNode, [ParseContext _]) =>
      new ng.VariableAst(astNode.name, astNode.value, astNode.sourceSpan);

  @override
  ng.TemplateAst visitProperty(ast.PropertyAst astNode,
      [ParseContext context]) {
    var value = parser.parseBinding(astNode.value, _location(astNode), []);
    if (_bindToDirectives(context, astNode, value)) return null;
    return createElementPropertyAst(context.elementName, _getName(astNode),
        value, astNode.sourceSpan, schemaRegistry, (_, __, [___]) {});
  }

  bool _bindToDirectives(ParseContext context, ast.PropertyAst astNode,
      ASTWithSource value) {
    for (var directive in context.boundDirectives) {
      for (var inputKey in directive.directive.inputs.keys) {
        var inputValue = directive.directive.inputs[inputKey];
        if (inputValue == astNode.name) {
          directive.inputs.add(new ng.BoundDirectivePropertyAst(
              inputKey, inputValue, value, astNode.sourceSpan));
          return true;
        }
      }
    }
    return false;
  }

  void _bindLiteralToDirectives(ParseContext context,
      ast.AttributeAst astNode) {
    for (var directive in context.boundDirectives) {
      for (var inputKey in directive.directive.inputs.keys) {
        var inputValue = directive.directive.inputs[inputKey];
        if (inputValue == astNode.name) {
          directive.inputs.add(new ng.BoundDirectivePropertyAst(
              inputKey,
              inputValue,
              parser.wrapLiteralPrimitive(astNode.value, _location(astNode)),
              astNode.sourceSpan));
        }
      }
    }
  }

  static String _getName(ast.PropertyAst astNode) {
    if (astNode.unit != null) {
      return '${astNode.name}.${astNode.postfix}.${astNode.unit}';
    }
    if (astNode.postfix != null) {
      return '${astNode.name}.${astNode.postfix}';
    }
    return astNode.name;
  }

  @override
  ng.TemplateAst visitReference(ast.ReferenceAst astNode,
      [ParseContext context]) {
    for (var boundDirective in context.boundDirectives) {
      if (astNode.identifier == null ||
          astNode.identifier == boundDirective.directive.exportAs)
        return new ng.ReferenceAst(astNode.variable,
            identifierToken(boundDirective.directive.type), astNode.sourceSpan);
    }
    return new ng.ReferenceAst(
        astNode.variable, context.referenceValue, astNode.sourceSpan);
  }

  @override
  ng.TemplateAst visitText(ast.TextAst astNode, [ParseContext context]) =>
      new ng.TextAst(astNode.value,
          context.findNgContentIndex(TEXT_CSS_SELECTOR), astNode.sourceSpan);

  @override
  ng.TemplateAst visitBanana(ast.BananaAst astNode, [ParseContext _]) =>
      throw new UnimplementedError('Don\'t know how to handle bananas');

  @override
  ng.TemplateAst visitCloseElement(ast.CloseElementAst astNode,
      [ParseContext _]) =>
      throw new UnimplementedError('Don\'t know how to handle close elements');

  @override
  ng.TemplateAst visitComment(ast.CommentAst astNode, [ParseContext _]) =>
      throw new UnimplementedError('Don\'t know how to handle comments.');

  @override
  ng.TemplateAst visitExpression(ast.ExpressionAst astNode, [ParseContext _]) =>
      throw new UnimplementedError('Don\'t know how to handle expressions.');

  @override
  ng.TemplateAst visitStar(ast.StarAst astNode, [ParseContext _]) =>
      throw new UnimplementedError('Don\'t know how to handle stars.');

  List<T> _visitAll<T extends ng.TemplateAst>(
      List<ast.TemplateAst> astNodes, ParseContext context) {
    final results = <T>[];
    for (final astNode in astNodes) {
      final visitedNode = astNode.accept(this, context) as T;
      if (visitedNode != null) results.add(visitedNode);
    }
    return results;
  }

  List<CompileDirectiveMetadata> _matchElementDirectives(
          ParseContext context, ast.ElementAst astNode) =>
      _parseDirectives(_selector(context.directives), _elementSelector(astNode),
          context.directives);

  List<CompileDirectiveMetadata> _matchTemplateDirectives(
          ParseContext context, ast.EmbeddedTemplateAst astNode) =>
      _parseDirectives(_selector(context.directives),
          _templateSelector(astNode), context.directives);

  List<ng.DirectiveAst> _toAst(
      Iterable<CompileDirectiveMetadata> directiveMetas,
      SourceSpan sourceSpan,
      String elementName,
      String location) =>
      directiveMetas
          .map((directive) =>
      new ng.DirectiveAst(
          directive,
          [] /* inputs */,
          _convertProperties(directive, sourceSpan, elementName, location),
          _convertEvents(directive, sourceSpan, elementName, location),
          sourceSpan))
          .toList();

  List<ng.BoundElementPropertyAst> _convertProperties(
      CompileDirectiveMetadata directive,
      SourceSpan sourceSpan,
      String elementName,
      String location) {
    var result = [];
    for (var propName in directive.hostProperties.keys) {
      var expression = directive.hostProperties[propName];
      var exprAst = parser.parseBinding(expression, location, [] /* exports */);
      result.add(createElementPropertyAst(elementName, propName, exprAst,
          sourceSpan, schemaRegistry, (_, __, [___]) {}));
    }
    return result;
  }

  List<ng.BoundEventAst> _convertEvents(CompileDirectiveMetadata directive,
      SourceSpan sourceSpan, String elementName, String location) {
    var result = [];
    for (var eventName in directive.hostListeners.keys) {
      var expression = directive.hostListeners[eventName];
      var value =
      parser.parseAction(expression, location, const [] /* exports */);
      result.add(new ng.BoundEventAst(eventName, value, sourceSpan));
    }
    return result;
  }

  CssSelector _elementSelector(ast.ElementAst astNode) {
    final attributes = [];
    for (var attr in astNode.attributes) {
      attributes.add([attr.name, attr.value]);
    }
    for (var property in astNode.properties) {
      attributes.add([property.name, property.value]);
    }
    for (var event in astNode.events) {
      attributes.add([event.name, event.value]);
    }
    return createElementCssSelector(astNode.name, attributes);
  }

  CssSelector _templateSelector(ast.EmbeddedTemplateAst astNode) {
    final attributes = [];
    for (var attr in astNode.attributes) {
      attributes.add([attr.name, attr.value]);
    }
    for (var property in astNode.properties) {
      attributes.add([property.name, property.value]);
    }
    for (var event in astNode.events) {
      attributes.add([event.name, event.value]);
    }
    return createElementCssSelector(TEMPLATE_ELEMENT, attributes);
  }

  SelectorMatcher _selector(List<CompileDirectiveMetadata> directives) {
    final SelectorMatcher selectorMatcher = new SelectorMatcher();
    for (var directive in directives) {
      var selector = CssSelector.parse(directive.selector);
      selectorMatcher.addSelectables(selector, directive);
    }
    return selectorMatcher;
  }

  List<CompileDirectiveMetadata> _parseDirectives(
      SelectorMatcher selectorMatcher,
      CssSelector elementCssSelector,
      List<CompileDirectiveMetadata> directives) {
    var matchedDirectives = new Set();
    selectorMatcher.match(elementCssSelector, (selector, directive) {
      matchedDirectives.add(directive);
    });
    // We return the directives in the same order that they are present in the
    // Component, not the order that they match in the html.
    return directives.where(matchedDirectives.contains).toList();
  }

  static String _location(ast.TemplateAst astNode) =>
      astNode.isSynthetic ? '' : astNode.sourceSpan.start.toString();
}

class ParseContext {
  final List<CompileDirectiveMetadata> directives;
  final String elementName;
  final CompileTokenMetadata referenceValue;
  final List<ng.DirectiveAst> boundDirectives;
  final SelectorMatcher ngContentIndexMatcher;
  final int wildcardNgContentIndex;

  ParseContext({this.directives,
    this.elementName,
    this.referenceValue,
    this.boundDirectives = const [],
    this.ngContentIndexMatcher,
    this.wildcardNgContentIndex});

  ParseContext withElementName(String name) =>
      new ParseContext(
          elementName: name,
          directives: directives,
          referenceValue: referenceValue);

  ParseContext forTemplate() =>
      new ParseContext(
          elementName: TEMPLATE_ELEMENT,
          directives: directives,
          referenceValue: identifierToken(Identifiers.TemplateRef));

  ParseContext bindDirectives(List<ng.DirectiveAst> directiveAsts) {
    var matcher;
    var wildcardIndex;
    var component = directiveAsts.firstWhere(
            (directive) => directive.directive.isComponent,
        orElse: () => null);
    if (component != null) {
      matcher = new SelectorMatcher();
      var ngContextSelectors = component.directive.template.ngContentSelectors;
      for (var i = 0; i < ngContextSelectors.length; i++) {
        var selector = ngContextSelectors[i];
        if (selector == '*') {
          wildcardIndex = i;
        } else {
          matcher.addSelectables(CssSelector.parse(ngContextSelectors[i]), i);
        }
      }
    }
    return new ParseContext(
        elementName: elementName,
        directives: directives,
        boundDirectives: directiveAsts,
        referenceValue: referenceValue,
        ngContentIndexMatcher: matcher,
        wildcardNgContentIndex: wildcardIndex);
  }

  int findNgContentIndex(CssSelector selector) {
    if (ngContentIndexMatcher == null) return null;
    var ngContentIndices = [];
    ngContentIndexMatcher.match(selector, (selector, ngContentIndex) {
      ngContentIndices.add(ngContentIndex);
    });
    ngContentIndices.sort();
    return ngContentIndices.isNotEmpty
        ? ngContentIndices.first
        : wildcardNgContentIndex;
  }
}

/// Visitor which filters elements that are not supported in angular templates.
class ElementFilter implements ast.TemplateAstVisitor<ast.TemplateAst, bool> {
  List<T> visitAll<T extends ast.TemplateAst>(Iterable<T> astNodes,
      [bool hasNgNonBindable = false]) {
    final result = <T>[];
    for (final node in astNodes) {
      final visited = node.accept(this, hasNgNonBindable);
      if (visited != null) result.add(visited);
    }
    return result;
  }

  @override
  ast.TemplateAst visitElement(ast.ElementAst astNode,
      [bool hasNgNonBindable]) {
    if (_filterElement(astNode, hasNgNonBindable)) {
      return null;
    }
    hasNgNonBindable =
        hasNgNonBindable || _hasNgNOnBindable(astNode.attributes);
    return new ast.ElementAst.from(
        astNode, astNode.name, astNode.closeComplement,
        attributes: visitAll(astNode.attributes, hasNgNonBindable),
        childNodes: visitAll(astNode.childNodes, hasNgNonBindable),
        events: visitAll(astNode.events, hasNgNonBindable),
        properties: visitAll(astNode.properties, hasNgNonBindable),
        references: visitAll(astNode.references, hasNgNonBindable),
        bananas: visitAll(astNode.bananas, hasNgNonBindable),
        stars: visitAll(astNode.stars, hasNgNonBindable));
  }

  @override
  ast.TemplateAst visitEmbeddedContent(ast.EmbeddedContentAst astNode,
          [bool hasNgNonBindable]) =>
      hasNgNonBindable
          ? new ast.ElementAst.from(
              astNode, NG_CONTENT_ELEMENT, astNode.closeComplement,
              childNodes: visitAll(astNode.childNodes, hasNgNonBindable))
          : astNode;

  @override
  ast.TemplateAst visitInterpolation(ast.InterpolationAst astNode,
          [bool hasNgNonBindable]) =>
      hasNgNonBindable
          ? new ast.TextAst.from(astNode, '{{${astNode.value}}}')
          : astNode;

  static bool _filterElement(ast.ElementAst astNode, bool hasNgNonBindable) =>
      _filterScripts(astNode) ||
      _filterStyles(astNode) ||
      _filterStyleSheets(astNode, hasNgNonBindable);

  static bool _filterStyles(ast.ElementAst astNode) =>
      astNode.name.toLowerCase() == STYLE_ELEMENT;

  static bool _filterScripts(ast.ElementAst astNode) =>
      astNode.name.toLowerCase() == SCRIPT_ELEMENT;

  static bool _filterStyleSheets(
      ast.ElementAst astNode, bool hasNgNonBindable) {
    if (astNode.name != LINK_ELEMENT) return false;
    var href = _findHref(astNode.attributes);
    return hasNgNonBindable || isStyleUrlResolvable(href?.value);
  }

  static ast.AttributeAst _findHref(List<ast.AttributeAst> attributes) {
    for (var attr in attributes) {
      if (attr.name.toLowerCase() == LINK_STYLE_HREF_ATTR) return attr;
    }
    return null;
  }

  bool _hasNgNOnBindable(List<ast.AttributeAst> attributes) {
    for (var attr in attributes) {
      if (attr.name == NG_NON_BINDABLE_ATTR) return true;
    }
    return false;
  }

  @override
  ast.TemplateAst visitAttribute(ast.AttributeAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitBanana(ast.BananaAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitCloseElement(ast.CloseElementAst astNode, [bool _]) =>
      astNode;

  @override
  ast.TemplateAst visitComment(ast.CommentAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitEmbeddedTemplate(ast.EmbeddedTemplateAst astNode,
          [bool _]) =>
      astNode;

  @override
  ast.TemplateAst visitEvent(ast.EventAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitExpression(ast.ExpressionAst astNode, [bool _]) =>
      astNode;

  @override
  ast.TemplateAst visitLetBinding(ast.LetBindingAst astNode, [bool _]) =>
      astNode;

  @override
  ast.TemplateAst visitProperty(ast.PropertyAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitReference(ast.ReferenceAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitStar(ast.StarAst astNode, [bool _]) => astNode;

  @override
  ast.TemplateAst visitText(ast.TextAst astNode, [bool _]) => astNode;
}
