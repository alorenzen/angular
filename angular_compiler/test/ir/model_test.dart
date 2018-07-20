import 'package:angular_compiler/src/ir/model.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

import 'ir_output.dart';

void main() {
  group('IR Model', () {
    Component component;
    setUp(() {
      component =
          Component('TestComponent', ChangeDetectionStrategy.checkAlways);
    });
    test('simple ComponentView', () {
      expectOutput(
        ComponentView(component),
        r'''
          class ViewTestComponent extends AppView<TestComponent> {
            ViewTestComponent(AppView<dynamic> parentView, int parentIndex) 
                : super(ViewType.component, {}, parentView, parentIndex, ChangeDetectionStrategy.CheckAlways);
            
            ComponentRef<TestComponent> build() {}
            void detectChangesInternal() {}
            void destroyInternal() {}
          }
          ''',
      );
    });

    test('simple HostView', () {
      expectOutput(
        HostView(ComponentView(component), component),
        r'''
          class _ViewTestComponentHost extends AppView<TestComponent> {
            _ViewTestComponentHost(AppView<dynamic> parentView, int parentIndex) 
                : super(ViewType.host, {}, parentView, parentIndex, ChangeDetectionStrategy.CheckAlways);
                
            ViewTestComponent _foo_0;
          
            ComponentRef<TestComponent> build() {
              _foo_0 = new ViewTestComponent(this, 0);
            }
            void detectChangesInternal() {
              _foo_0.detectChanges();
            }
            void destroyInternal() {
              _foo_0?.destroy();
            }
      }
      ''',
      );
    });

    test('ComponentView with TextElement', () {
      expectOutput(
        ComponentView(component, children: [TextNode('Hello, World')]),
        r'''
          class ViewTestComponent extends AppView<TestComponent> {
            ViewTestComponent(AppView<dynamic> parentView, int parentIndex)
                : super(ViewType.component, {}, parentView, parentIndex,
                    ChangeDetectionStrategy.CheckAlways);
                    
            ComponentRef<TestComponent> build() {
              _foo_0 = new Text('Hello, World');
            }
            void detectChangesInternal() {}
            void destroyInternal() {}
          }
        ''',
      );
    });

    test('ComponentView with Interpolation', () {
      expectOutput(
        ComponentView(component, children: [InterpolationNode(AST('foo'))]),
        r'''
          class ViewTestComponent extends AppView<TestComponent> {
            ViewTestComponent(AppView<dynamic> parentView, int parentIndex)
                : super(ViewType.component, {}, parentView, parentIndex,
                    ChangeDetectionStrategy.CheckAlways);
                    
             Text _foo_0;
                    
            ComponentRef<TestComponent> build() {
              _foo_0 = new Text('');
            }
            void detectChangesInternal() {
              final currVal = _ctx.foo;
              if (checkBinding(_foo_0, currVal)) {
                _foo_0 = currVal;
              }
            }
            void destroyInternal() {}
          }
        ''',
      );
    });
  });
}

expectOutput(View view, String expectedOutput) {
  var outputBuilder = view.accept(OutputIRVisitor(ReferenceService()));
  var emitter = DartEmitter();
  var formatter = DartFormatter();
  var actualOutput = formatter.format('${outputBuilder.accept(emitter)}');
  expect(actualOutput, formatter.format(expectedOutput));
}
