import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

/*
      union-type-spec:
         "union" union-body

      union-body:
         "switch" "(" declaration ")" "{"
            case-spec
            case-spec *
            [ "default" ":" declaration ";" ]
         "}"

      case-spec:
        ( "case" value ":")
        ( "case" value ":") *
        declaration ";"
 */
void main() {
  group('union parsing', () {
    test('union with default', () {
      final result = RPCParser.parse('''
      union read_result switch (int errno) {
 	      case 0:
 		      opaque data[1024];
 	      default:
 		      void;
 	    };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<UnionTypeDefinition>());
      expect(result.value.types[0].name, equals('read_result'));
      final type = result.value.types[0].type as UnionTypeSpecifier;
      expect(type.arms.length, 1);
      expect(type.arms[0].labels.length, 1);
      expect((type.arms[0].labels[0] as IntegerLiteral).value, 0);
      expect(type.arms[0].type, isA<OpaqueTypeDefinition>());

      // default
      expect(type.otherwise, isNotNull);
      expect(type.otherwise!.type, isA<VoidTypeSpecifier>());
    });
    test('union with nested struct', () {
      final result = RPCParser.parse('''
      union stringlist switch (bool opted) {
        case TRUE:
          struct {
            string item<>;
            stringlist *next;
          } element;
        case FALSE:
          void;
      };
      ''');
      expect(result is Success, true);
    });
  });
}
