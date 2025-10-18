import 'package:petitparser/debug.dart';
import 'package:petitparser/petitparser.dart';

import 'ast.dart';
import 'grammar.dart';

/// Parser for ONC-RPC/XDR specification files
///
/// Parses .x files containing RPC program definitions, XDR type definitions,
/// constants, and other ONC-RPC constructs according to RFC 4506 and RFC 5531.
class RPCParser {
  /// Parses an RPC/XDR specification string
  ///
  /// Returns a [Result] containing either a successfully parsed [Specification]
  /// or error information if parsing fails.
  static Result<Specification> parse(
    final String input, {
    final bool debug = false,
    final bool strict = false,
  }) {
    final definition = RPCParserDefinition(strict);
    // Add better error messages to the parser
    final parser = (definition.build() as Parser<Specification>).end();
    try {
      final result = debug ? trace(parser).parse(input) : parser.parse(input);

      // If parsing failed, enhance error message with token context
      if (result is Failure) {
        return _enhanceFailureMessage(result, input);
      }

      return result;
    } on FormatException catch (e) {
      // Convert validation exceptions to parse failures
      return Failure(input, 0, e.message);
    }
  }

  /// Enhances a failure message with line/column and a caret snippet for context
  static Failure _enhanceFailureMessage(
    final Failure failure,
    final String input,
  ) {
    final position = failure.position;
    final buffer = failure.buffer;

    // Calculate line and column
    final lineColumn = _getLineAndColumn(buffer, position);
    final line = lineColumn.line;
    final column = lineColumn.column;

    // Get a line snippet for context
    final lineSnippet = _getLineSnippet(buffer, position);

    // Use the original parser message
    final baseMessage = failure.message;

    // Create an enhanced error message
    final enhancedMessage = '''
$baseMessage
  at line $line, column $column
  $lineSnippet''';

    return Failure(buffer, position, enhancedMessage);
  }

  /// Gets the line and column number for a position in the buffer
  static ({int line, int column}) _getLineAndColumn(
    final String buffer,
    final int position,
  ) {
    int line = 1;
    int column = 1;

    for (int i = 0; i < position && i < buffer.length; i++) {
      if (buffer[i] == '\n') {
        line++;
        column = 1;
      } else {
        column++;
      }
    }

    return (line: line, column: column);
  }

  /// Gets a snippet of the line where the error occurred
  static String _getLineSnippet(final String buffer, final int position) {
    if (position >= buffer.length) {
      return '';
    }

    // Find the start of the current line
    int lineStart = position;
    while (lineStart > 0 && buffer[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Find the end of the current line
    int lineEnd = position;
    while (lineEnd < buffer.length && buffer[lineEnd] != '\n') {
      lineEnd++;
    }

    // Extract the line
    final line = buffer.substring(lineStart, lineEnd);

    // Calculate the column position
    final column = position - lineStart;

    // Create pointer to the error position
    final pointer = ' ' * column + '^';

    return '  $line\n  $pointer';
  }
}

class RPCParserDefinition extends RPCGrammarDefinition {
  // ignore: avoid_positional_boolean_parameters
  RPCParserDefinition([super.strict = false]);

  final Set<String> constants = {};
  final Set<String> references = {};

  @override
  Parser<Specification> specification() => super.specification().map((value) {
        final values = value as List<dynamic>;
        final definitions = values[1] as List<dynamic>;
        final programs = <Program>[];
        final constants = <Constant<Value>>[];
        final types = <TypeDefinition>[];

        for (final dynamic d in definitions) {
          if (d is Program) programs.add(d);
          if (d is Constant<Value>) constants.add(d);
          if (d is TypeDefinition) types.add(d);
        }

        // Validate all referenced constants are defined
        final undefined = references.difference(this.constants);
        if (undefined.isNotEmpty) {
          throw FormatException(
            'Undefined constant(s): ${undefined.join(', ')}',
          );
        }

        return Specification(programs, constants, types);
      });

  @override
  Parser<Program> programDefinition() => super.programDefinition().map((args) {
        final argsList = args as List<dynamic>;
        final identifier = argsList[1] as String;
        final constant = argsList[6] as int;
        final versions = List<Version>.from(argsList[3] as List<dynamic>);
        return Program(identifier, constant, versions);
      });

  @override
  Parser<TypeDefinition> typeDefinition() =>
      super.typeDefinition().map((args) => args as TypeDefinition);

  @override
  Parser<TypeDefinition> typedefDefinition() =>
      super.typedefDefinition().map((args) {
        final argsList = args as List<dynamic>;
        if (argsList[1] is VoidTypeDefinition) {
          throw const FormatException(
            'typedef void; is not valid. void can only be used in union',
          );
        }
        return argsList[1] as TypeDefinition;
      });

  @override
  Parser<TypeDefinition> structPointerDefinition() =>
      super.structPointerDefinition().map((args) {
        final argsList = args as List<dynamic>;
        return PointerTypeDefinition(
          argsList[4] as String,
          PointerTypeSpecifier(
            UserDefinedTypeSpecifier(argsList[2] as String),
          ),
        );
      });

  @override
  Parser<TypeDefinition> declaration() => super.declaration().map((args) {
        if (args is TypeDefinition) return args;
        throw FormatException('Declaration did not produce a type: $args');
      });

  @override
  Parser typeDeclaration() => super.typeDeclaration().map((args) {
        final argsList = args as List<dynamic>;
        final offset = argsList[0] is String || argsList[0] == null ? 1 : 0;
        final type = argsList[offset + 0] as TypeSpecifier;
        final name = argsList[offset + 1] as String;
        final dimensions = argsList[offset + 2];
        if (dimensions is ArraySpecifier) {
          return TypeDefinition(name, type, List.filled(1, dimensions));
        } else if (dimensions is List<dynamic>) {
          final List<ArraySpecifier> list = [];
          for (final dim in dimensions) {
            list.add(dim as ArraySpecifier);
          }
          return TypeDefinition(name, type, list);
        }
        return TypeDefinition(name, type);
      });

  @override
  Parser opaqueDeclaration() => super.opaqueDeclaration().map((args) {
        final argsList = args as List<dynamic>;
        final dimensions = argsList[2] as ArraySpecifier;
        return OpaqueTypeDefinition(
          argsList[1] as String,
          OpaqueTypeSpecifier(),
          [dimensions],
        );
      });

  @override
  Parser stringDeclaration() => super.stringDeclaration().map((args) {
        final argsList = args as List<dynamic>;
        final dimensions = argsList[2] as ArraySpecifier;
        return StringTypeDefinition(
          argsList[1] as String,
          StringTypeSpecifier(),
          [dimensions],
        );
      });

  @override
  Parser pointerDeclaration() => super.pointerDeclaration().map((args) {
        final argsList = args as List<dynamic>;
        final type = argsList[0] as TypeSpecifier;
        final name = argsList[2] as String;

        return PointerTypeDefinition(name, PointerTypeSpecifier(type));
      });

  @override
  Parser voidDeclaration() =>
      super.voidDeclaration().map((args) => VoidTypeDefinition());

  @override
  Parser fixedLengthArrayDeclaration() =>
      super.fixedLengthArrayDeclaration().map((args) {
        final argsList = args as List<dynamic>;
        final value = argsList[1];
        final dimensions = value is Value ? value : _parseValue(value);
        // Track referenced constants for validation
        if (dimensions is ReferenceValue) {
          references.add(dimensions.name);
        }
        return ArraySpecifier(dimensions, isFixedLength: true);
      });

  @override
  Parser variableLengthArrayDeclaration() =>
      super.variableLengthArrayDeclaration().map((args) {
        final argsList = args as List<dynamic>;
        final value = argsList[1];
        Value dimensions;
        if (value == null) {
          dimensions = Value.literal(-1);
        } else if (value is Value) {
          dimensions = value;
          // Track referenced constants for validation
          if (dimensions is ReferenceValue) {
            references.add(dimensions.name);
          }
        } else {
          dimensions = _parseValue(value);
        }
        return ArraySpecifier(dimensions, isFixedLength: false);
      });

  @override
  Parser<TypeDefinition> enumDefinition() => super.enumDefinition().map((args) {
        final argsList = args as List<dynamic>;
        final identifier = argsList[1] as String;
        final values = List<Constant<Value>>.from(argsList[2] as List<dynamic>);
        return EnumTypeDefinition(identifier, EnumTypeSpecifier(values));
      });

  @override
  Parser<List<Constant<Value>>> enumBody() => super.enumBody().map((args) {
        final argsList = args as List<dynamic>;
        final List<Constant<Value>> constants = List.castFrom(
          (argsList[1] as SeparatedList<dynamic, dynamic>).elements,
        );
        return constants;
      });

  @override
  Parser<Constant<Value>> enumPart() => super.enumPart().map((args) {
        final argsList = args as List<dynamic>;
        final value = argsList[2];
        if (value is ReferenceValue) {
          references.add(value.name);
          return Constant<Value>(
            argsList[0] as String,
            Value.reference(value.name),
          );
        }
        return Constant<Value>(argsList[0] as String, value as Value);
      });

  @override
  Parser<Value> value() => super.value().map((args) {
        // args is either an int literal or a string identifier
        if (args is int) {
          return Value.literal(args);
        } else if (args is String) {
          return Value.reference(args);
        }
        throw ArgumentError('Invalid value type: $args');
      });

  @override
  Parser<StructTypeDefinition> structDefinition() =>
      super.structDefinition().map((args) {
        final argsList = args as List<dynamic>;
        return StructTypeDefinition(
          argsList[1] as String,
          StructTypeSpecifier(argsList[2] as List<TypeDefinition>),
        );
      });

  @override
  Parser<List<TypeDefinition>> structBody() => super.structBody().map((args) {
        final argsList = args as List<dynamic>;
        return List<TypeDefinition>.from(argsList[1] as List<dynamic>);
      });

  @override
  Parser<TypeDefinition> structPart() => super.structPart().map((args) {
        final argsList = args as List<dynamic>;
        return argsList[0] as TypeDefinition;
      });

  @override
  Parser<UnionTypeDefinition> unionDefinition() =>
      super.unionDefinition().map((args) {
        final argsList = args as List<dynamic>;
        return UnionTypeDefinition(
          argsList[1] as String,
          argsList[2] as UnionTypeSpecifier,
        );
      });

  @override
  Parser<dynamic> unionBody() => super.unionBody().map((args) {
        final argsList = args as List<dynamic>;
        return UnionTypeSpecifier(
          argsList[2] as TypeDefinition,
          List<UnionArm>.from(argsList[5] as List<dynamic>),
          argsList[6] as TypeDefinition?,
        );
      });

  @override
  Parser<Value> unionCaseLabel() => super.unionCaseLabel().map((args) {
        final argsList = args as List<dynamic>;
        return argsList[1] as Value;
      });

  @override
  Parser<UnionArm> unionCaseSpecification() =>
      super.unionCaseSpecification().map((args) {
        final argsList = args as List<dynamic>;
        return UnionArm(
          List<Value>.from(argsList[0] as List<dynamic>),
          argsList[1] as TypeDefinition,
        );
      });

  @override
  Parser<TypeDefinition> unionDefault() => super.unionDefault().map((args) {
        final argsList = args as List<dynamic>;
        return argsList[2] as TypeDefinition;
      });

  @override
  Parser<Constant<Value>> constantDefinition() =>
      super.constantDefinition().map((args) {
        final argsList = args as List<dynamic>;
        final identifier = argsList[1] as String;
        final value = argsList[3] as int;
        constants.add(identifier);
        return Constant<Value>(identifier, Value.literal(value));
      });

  @override
  Parser<Version> versionDefinition() => super.versionDefinition().map((args) {
        final argsList = args as List<dynamic>;
        final identifier = argsList[1] as String;
        final constant = argsList[6] as int;
        final procedures = List<Procedure>.from(argsList[3] as List<dynamic>);
        return Version(identifier, constant, procedures);
      });

  @override
  Parser<Procedure> procedureDefinition() =>
      super.procedureDefinition().map((args) {
        final argsList = args as List<dynamic>;
        final ret = argsList[0] as TypeSpecifier;
        final identifier = argsList[1] as String;
        final constant = argsList[6] as int;
        final List<TypeSpecifier> params =
            List.castFrom(argsList[3] as List<dynamic>);
        return Procedure(identifier, ret, params, constant);
      });

  @override
  Parser<TypeSpecifier> procedureReturn() =>
      super.procedureReturn().map((value) {
        if (value == 'void') {
          return VoidTypeSpecifier();
        }
        return value as TypeSpecifier;
      });

  @override
  Parser<List<TypeSpecifier>> procedureArguments() =>
      super.procedureArguments().map((args) {
        final argsList = args as List<dynamic>;
        return List<TypeSpecifier>.filled(
          1,
          argsList[0] as TypeSpecifier,
          growable: true,
        )..addAll(argsList[1] as List<TypeSpecifier>);
      });

  @override
  Parser<TypeSpecifier> procedureFirstArg() =>
      super.procedureFirstArg().map((value) {
        if (value == 'void') {
          return VoidTypeSpecifier();
        }
        return value as TypeSpecifier;
      });

  @override
  Parser<TypeSpecifier> stringTypeSpecifier() =>
      super.stringTypeSpecifier().map((a) => StringTypeSpecifier());

  @override
  Parser<TypeSpecifier> voidTypeSpecifier() =>
      super.voidTypeSpecifier().map((a) => VoidTypeSpecifier());

  @override
  Parser<List<TypeSpecifier>> procedureOptionalArgs() => super
      .procedureOptionalArgs()
      .map((value) => List<TypeSpecifier>.from(value as Iterable<dynamic>));

  @override
  Parser<TypeSpecifier> procedureOptionalArg() =>
      super.procedureOptionalArg().map((value) {
        final valueList = value as List<dynamic>;
        return valueList[1] as TypeSpecifier;
      });

  @override
  Parser<TypeSpecifier> procedureType() => super.procedureType().map((value) {
        if (value == 'string') {
          return StringTypeSpecifier();
        }
        return value as TypeSpecifier;
      });

  @override
  Parser<String> identifier() => super.identifier().map((value) {
        final valueStr = value as String;
        final id = valueStr.trim();
        if (keywords.contains(id)) {
          throw FormatException('Reserved word "$id"');
        }
        return id;
      });

  @override
  Parser<int> constant() => super.constant().map(
        (value) =>
            // Must be an int (from decimal/hex/octal)
            value as int,
      );

  @override
  // ignore: unnecessary_lambdas
  Parser<int> decimalConstant() =>
      super.decimalConstant().map((value) => int.parse(value as String));

  @override
  Parser<int> hexadecimalConstant() => super.hexadecimalConstant().map((value) {
        final valueList = value as List<dynamic>;
        return int.parse(valueList[1] as String, radix: 16);
      });

  @override
  Parser<int> octalConstant() => super
      .octalConstant()
      .map((value) => int.parse(value as String, radix: 8));

  @override
  Parser<TypeSpecifier> typeSpecifier() => super.typeSpecifier().map((args) {
        if (args is TypeSpecifier) return args;
        if (args is String) return UserDefinedTypeSpecifier(args);

        final argsList = args as List<dynamic>;
        throw FormatException('Unknown type specifier ${argsList[0]}');
      });

  @override
  Parser<TypeSpecifier> intTypeSpecifier() =>
      super.intTypeSpecifier().map((args) {
        final argsList = args as List<dynamic>;
        return IntTypeSpecifier(isUnsigned: argsList[0] != null);
      });

  @override
  Parser<TypeSpecifier> hyperTypeSpecifier() =>
      super.hyperTypeSpecifier().map((args) {
        final argsList = args as List<dynamic>;
        return HyperTypeSpecifier(isUnsigned: argsList[0] != null);
      });

  @override
  Parser floatTypeSpecifier() =>
      super.floatTypeSpecifier().map((value) => FloatTypeSpecifier());

  @override
  Parser doubleTypeSpecifier() =>
      super.doubleTypeSpecifier().map((value) => DoubleTypeSpecifier());

  @override
  Parser quadrupleTypeSpecifier() =>
      super.quadrupleTypeSpecifier().map((value) => QuadrupleTypeSpecifier());

  @override
  Parser boolTypeSpecifier() =>
      super.boolTypeSpecifier().map((value) => BooleanTypeSpecifier());

  @override
  Parser cStyleTypeSpecifier() => super.cStyleTypeSpecifier().map((value) {
        final type = value as String;
        switch (type) {
          case 'int32_t':
            return IntTypeSpecifier(isUnsigned: false);
          case 'uint32_t':
            return IntTypeSpecifier(isUnsigned: true);
          case 'int64_t':
            return HyperTypeSpecifier(isUnsigned: false);
          case 'uint64_t':
            return HyperTypeSpecifier(isUnsigned: true);
          default:
            throw FormatException('Unknown C-style type: $type');
        }
      });

  @override
  Parser enumTypeSpecifier() => super.enumTypeSpecifier().map((args) {
        final argsList = args as List<dynamic>;
        // Legacy mode 'enum type identifier;'
        if (argsList[1] is String) {
          return UserDefinedTypeSpecifier(argsList[1] as String);
        }
        return EnumTypeSpecifier(argsList[1] as List<Constant<Value>>);
      });

  @override
  Parser structTypeSpecifier() => super.structTypeSpecifier().map((args) {
        final argsList = args as List<dynamic>;
        // Legacy mode 'struct type identifier;'
        if (argsList[1] is String) {
          return UserDefinedTypeSpecifier(argsList[1] as String);
        }
        return StructTypeSpecifier(argsList[1] as List<TypeDefinition>);
      });

  @override
  Parser unionTypeSpecifier() => super.unionTypeSpecifier().map((args) {
        final argsList = args as List<dynamic>;
        return argsList[1] as UnionTypeSpecifier;
      });

  Value _parseValue(dynamic value) {
    if (value is String) {
      // Check if it's a numeric constant that was parsed as a string
      final intValue = int.tryParse(value);
      if (intValue != null) {
        return Value.literal(intValue);
      }
      // It's an identifier reference - track it for validation
      references.add(value);
      return Value.reference(value);
    } else if (value is int) {
      return Value.literal(value);
    } else {
      // Fallback - treat as identifier reference
      final ref = value.toString();
      references.add(ref);
      return Value.reference(ref);
    }
  }
}
