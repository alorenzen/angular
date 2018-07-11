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
          new Component('TestComponent', ChangeDetectionStrategy.checkAlways);
    });
    test('simple ComponentView', () {
      expectOutput(
        new ComponentView(component),
        r'''
          class ViewTestComponent extends AppView<TestComponent> {
            ViewTestComponent(AppView<dynamic> parentView, int parentIndex) 
                : super(ViewType.component, {}, parentView, parentIndex, ChangeDetectionStrategy.CheckAlways);
            
            ComponentRef<TestComponent> build();
            void detectChangesInternal();
            void destroyInternal();
          }
          ''',
      );
    });

    test('simple HostView', () {
      expectOutput(
        new HostView(new ComponentView(component), component),
        r'''
          class _ViewTestComponentHost extends AppView<TestComponent> {
            _ViewTestComponentHost(AppView<dynamic> parentView, int parentIndex) 
                : super(ViewType.host, {}, parentView, parentIndex, ChangeDetectionStrategy.CheckAlways);
          
            ComponentRef<TestComponent> build();
            void detectChangesInternal();
            void destroyInternal() {
              _compView?.destroy();
            }
      }
      ''',
      );
    });
  });
}

expectOutput(View view, String expectedOutput) {
  var outputBuilder = view.accept(new OutputIRVisitor());
  var emitter = new DartEmitter();
  var formatter = new DartFormatter();
  var actualOutput = formatter.format('${outputBuilder.accept(emitter)}');
  expect(actualOutput, formatter.format(expectedOutput));
}
