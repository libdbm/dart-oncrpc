import 'package:petitparser/petitparser.dart';

///
/// This is actually a slight extension of the RFC4506/RFC5331 grammar
/// - "unsigned" can stand alone, but in RFC4506 it should be followed by
///   'int' or 'hyper'
/// - procedures can use 'string' in the type specifier slot as well as
///   'void'
/// - it includes direct support for come standard C types
///
class RPCGrammarDefinition extends GrammarDefinition {
  // ignore: avoid_positional_boolean_parameters
  RPCGrammarDefinition([this._strict = true]);

  final Set<String> keywords = {
    'bool',
    'case',
    'const',
    'default',
    'double',
    'quadruple',
    'enum',
    'float',
    'hyper',
    'int',
    'opaque',
    'string',
    'struct',
    'switch',
    'typedef',
    'union',
    'unsigned',
    'void',
    // C-style type aliases
    'int32_t',
    'uint32_t',
    'int64_t',
    'uint64_t',
  };
  final bool _strict;

  bool get strict => _strict;

  @override
  Parser start() => ref<dynamic>(specification);

  /*
  ☑︎   specification:
           definition *

  ☑︎   definition:
           type-def
         | constant-def
         | program-def

  ☑︎   type-def:
           "typedef" declaration ";"
         | "enum" identifier enum-body ";"
         | "struct" identifier struct-body ";"
         | "union" identifier union-body ";"

  ☑︎   constant-def:
         "const" identifier "=" constant ";"

  ☑︎   program-def:
         "program" identifier "{"
            version-def
            version-def *
         "}" "=" constant ";"

  ☑︎   version-def:
         "version" identifier "{"
             procedure-def
             procedure-def *
         "}" "=" constant ";"

  ☑︎   procedure-def:
         proc-return identifier "(" proc-firstarg
           ("," type-specifier )* ")" "=" constant ";"

  ☑︎   proc-return: "void" | type-specifier

  ☑︎   proc-firstarg: "void" | type-specifier

  ☑︎   declaration:
           type-specifier identifier
         | type-specifier identifier "[" value "]"
         | type-specifier identifier "<" [ value ] ">"
         | "opaque" identifier "[" value "]"
         | "opaque" identifier "<" [ value ] ">"
         | "string" identifier "<" [ value ] ">"
         | type-specifier "*" identifier
         | "void"

  ☑︎   value:
           constant
         | identifier

  ☑︎   constant:
         decimal-constant | hexadecimal-constant | octal-constant

  ☑︎   type-specifier:
           [ "unsigned" ] "int"
         | [ "unsigned" ] "hyper"
         | "float"
         | "double"
         | "quadruple"
         | "bool"
         | enum-type-spec
         | struct-type-spec
         | union-type-spec
         | identifier

  ☑︎  enum-type-spec:
         "enum" enum-body

  ☑︎  enum-body:
         "{"
            ( identifier "=" value )
            ( "," identifier "=" value )*
         "}"

  ☑︎   struct-type-spec:
         "struct" struct-body

  ☑︎   struct-body:
         "{"
            ( declaration ";" )
            ( declaration ";" )*
         "}"

  ☑︎  union-type-spec:
         "union" union-body

  ☑︎   union-body:
         "switch" "(" declaration ")" "{"
            case-spec
            case-spec *
            [ "default" ":" declaration ";" ]
         "}"

  ☑︎   case-spec:
        ( "case" value ":")
        ( "case" value ":") *
        declaration ";"


   */

  /*
   * specification:
   *   definition *
   */
  Parser specification() =>
      ref<dynamic>(space).optional() & ref<dynamic>(definition).star();

  /*
   * definition:
   *     type-def
   *   | constant-def
   *   | program-def
   */
  Parser definition() =>
      ref<dynamic>(typeDefinition) |
      ref<dynamic>(programDefinition) |
      ref<dynamic>(constantDefinition);

  /*
   * type-def:
   *     "typedef" declaration ";"
   *   | "enum" identifier enum-body ";"
   *   | "struct" identifier struct-body ";"
   *   | "union" identifier union-body ";"
   */
  Parser typeDefinition() =>
      ref<dynamic>(typedefDefinition) |
      ref<dynamic>(enumDefinition) |
      ref<dynamic>(structDefinition) |
      ref<dynamic>(unionDefinition) |
      ref<dynamic>(structPointerDefinition);

  Parser typedefDefinition() =>
      ref<dynamic>(TYPEDEF) &
      ref<dynamic>(declaration) &
      ref<dynamic>(SEMICOLON);

  Parser enumDefinition() =>
      ref<dynamic>(ENUM) &
      ref<dynamic>(identifier) &
      ref<dynamic>(enumBody) &
      ref<dynamic>(SEMICOLON);

  Parser structDefinition() =>
      ref<dynamic>(STRUCT) &
      ref<dynamic>(identifier) &
      ref<dynamic>(structBody) &
      ref<dynamic>(SEMICOLON);

  Parser unionDefinition() =>
      ref<dynamic>(UNION) &
      ref<dynamic>(identifier) &
      ref<dynamic>(unionBody) &
      ref<dynamic>(SEMICOLON);

  Parser structPointerDefinition() {
    if (_strict) {
      return failure(message: 'legacy struct pointers are not supported');
    }
    return ref<dynamic>(TYPEDEF) &
        ref<dynamic>(STRUCT) &
        ref<dynamic>(identifier) &
        ref<dynamic>(STAR) &
        ref<dynamic>(identifier) &
        ref<dynamic>(SEMICOLON);
  }

  /*
   * constant-def:
   *   "const" identifier "=" constant ";"
   */
  Parser constantDefinition() =>
      ref<dynamic>(CONST) &
      ref<dynamic>(identifier) &
      ref<dynamic>(EQUALS) &
      ref<dynamic>(constant) &
      ref<dynamic>(SEMICOLON);

  /*
   * program-def:
   *    "program" identifier "{"
   *       version-def
   *       version-def *
   *    "}" "=" constant ";"
   */
  Parser programDefinition() =>
      ref<dynamic>(PROGRAM) &
      ref<dynamic>(identifier) &
      ref<dynamic>(OPEN_CURLY) &
      versionDefinition().plus() &
      ref<dynamic>(CLOSE_CURLY) &
      ref<dynamic>(EQUALS) &
      ref<dynamic>(constant) &
      ref<dynamic>(SEMICOLON);

  /*
   * version-def:
   *    "version" identifier "{"
   *        procedure-def
   *        procedure-def *
   *    "}" "=" constant ";"
   */
  Parser versionDefinition() =>
      ref<dynamic>(VERSION) &
      ref<dynamic>(identifier) &
      ref<dynamic>(OPEN_CURLY) &
      procedureDefinition().plus() &
      ref<dynamic>(CLOSE_CURLY) &
      ref<dynamic>(EQUALS) &
      ref<dynamic>(constant) &
      ref<dynamic>(SEMICOLON);

  /*
   * procedure-def:
   *    proc-return identifier "(" proc-firstarg
   *        ("," type-specifier )* ")" "=" constant ";"
   * proc-return: "void" | type-specifier
   * proc-firstarg: "void" | type-specifier
   */
  Parser procedureDefinition() =>
      ref<dynamic>(procedureReturn) &
      ref<dynamic>(identifier) &
      ref<dynamic>(OPEN_PAREN) &
      ref<dynamic>(procedureArguments) &
      ref<dynamic>(CLOSE_PAREN) &
      ref<dynamic>(EQUALS) &
      ref<dynamic>(constant) &
      ref<dynamic>(SEMICOLON);

  Parser procedureReturn() => voidTypeSpecifier() | ref<dynamic>(procedureType);

  Parser procedureArguments() =>
      ref<dynamic>(procedureFirstArg) & ref<dynamic>(procedureOptionalArgs);

  Parser procedureFirstArg() =>
      voidTypeSpecifier() | ref<dynamic>(procedureType);

  Parser procedureOptionalArgs() => ref<dynamic>(procedureOptionalArg).star();

  Parser procedureOptionalArg() =>
      ref<dynamic>(COMMA) & ref<dynamic>(typeSpecifier);

  Parser procedureType() =>
      _strict ? typeSpecifier() : stringTypeSpecifier() | typeSpecifier();

  /*
   * declaration:
   *      type-specifier identifier
   *    | type-specifier identifier "[" value "]"
   *    | "opaque" identifier "[" value "]"
   *    | "opaque" identifier "<" [ value ] ">"
   *    | "string" identifier "<" [ value ] ">"
   *    | type-specifier "*" identifier
   *    | "void"
   */
  Parser declaration() =>
      ref<dynamic>(voidDeclaration) |
      ref<dynamic>(opaqueDeclaration) |
      ref<dynamic>(stringDeclaration) |
      ref<dynamic>(pointerDeclaration) |
      ref<dynamic>(typeDeclaration);

  Parser typeDeclaration() =>
      ref<dynamic>(typeSpecifier) &
      ref<dynamic>(identifier) &
      ref<dynamic>(arrayDeclaration).star();

  Parser opaqueDeclaration() =>
      ref<dynamic>(OPAQUE) &
      ref<dynamic>(identifier) &
      ref<dynamic>(arrayDeclaration);

  Parser stringDeclaration() =>
      ref<dynamic>(STRING) &
      ref<dynamic>(identifier) &
      ref<dynamic>(variableLengthArrayDeclaration);

  Parser pointerDeclaration() =>
      ref<dynamic>(typeSpecifier) &
      ref<dynamic>(STAR) &
      ref<dynamic>(identifier);

  Parser voidDeclaration() => ref<dynamic>(VOID);

  Parser arrayDeclaration() =>
      ref<dynamic>(fixedLengthArrayDeclaration) |
      ref<dynamic>(variableLengthArrayDeclaration);

  Parser fixedLengthArrayDeclaration() =>
      ref<dynamic>(OPEN_SQUARE) &
      ref<dynamic>(value) &
      ref<dynamic>(CLOSE_SQUARE);

  Parser variableLengthArrayDeclaration() =>
      ref<dynamic>(OPEN_ANGLE) &
      ref<dynamic>(value).optional() &
      ref<dynamic>(CLOSE_ANGLE);

  /*
   * value:
   *      constant
   *    | identifier
   */
  Parser value() => ref<dynamic>(constant) | ref<dynamic>(identifier);

  /*
   * constant:
   *      decimal-constant | hexadecimal-constant | octal-constant
   */
  Parser constant() =>
      ref<dynamic>(decimalConstant) |
      ref<dynamic>(hexadecimalConstant) |
      ref<dynamic>(octalConstant);

  /*
   * type-specifier:
   *      [ "unsigned" ] "int"
   *    | [ "unsigned" ] "hyper"
   *    | "float"
   *    | "double"
   *    | "quadruple"
   *    | "bool"
   *    | enum-type-spec
   *    | struct-type-spec
   *    | union-type-spec
   *    | identifier
   */
  Parser typeSpecifier() =>
      ref<dynamic>(cStyleTypeSpecifier) | // C-style types before identifier
      ref<dynamic>(identifier) | // make sure int64 is recognized before int
      ref<dynamic>(hyperTypeSpecifier) |
      ref<dynamic>(intTypeSpecifier) |
      ref<dynamic>(floatTypeSpecifier) |
      ref<dynamic>(doubleTypeSpecifier) |
      ref<dynamic>(quadrupleTypeSpecifier) |
      ref<dynamic>(boolTypeSpecifier) |
      ref<dynamic>(enumTypeSpecifier) |
      ref<dynamic>(structTypeSpecifier) |
      ref<dynamic>(unionTypeSpecifier);

  /*
   * enum-type-spec:
   *      "enum" enum-body
   */
  Parser enumTypeSpecifier() {
    final base = ref<dynamic>(ENUM) & ref<dynamic>(enumBody);
    final alternative = ref<dynamic>(ENUM) & ref<dynamic>(identifier);
    if (_strict) {
      return base;
    }
    return base | alternative;
  }

  /*
   * enum-body:
   *    "{"
   *       ( identifier "=" value )
   *        ( "," identifier "=" value )*
   *    "}"
   */
  Parser enumBody() =>
      ref<dynamic>(OPEN_CURLY) &
      enumPart().plusSeparated(COMMA()) &
      ref<dynamic>(CLOSE_CURLY);

  Parser enumPart() =>
      ref<dynamic>(identifier) & ref<dynamic>(EQUALS) & ref<dynamic>(value);

  /*
   * struct-type-spec:
   *    "struct" struct-body
   */
  Parser structTypeSpecifier() {
    final base = ref<dynamic>(STRUCT) & ref<dynamic>(structBody);
    final alternative = ref<dynamic>(STRUCT) & ref<dynamic>(identifier);
    if (_strict) {
      return base;
    }
    return base | alternative;
  }

  /*
   * struct-body:
   *    "{"
   *         ( declaration ";" )
   *         ( declaration ";" )*
   *    "}"
   */
  Parser structBody() =>
      ref<dynamic>(OPEN_CURLY) &
      ref<dynamic>(structPart).plus() &
      ref<dynamic>(CLOSE_CURLY);

  Parser structPart() => ref<dynamic>(declaration) & ref<dynamic>(SEMICOLON);

  /*
   * union-type-spec:
   *    "union" union-body
   */
  Parser unionTypeSpecifier() => ref<dynamic>(UNION) & ref<dynamic>(unionBody);

  /*
   * union-body:
   *    "switch" "(" declaration ")" "{"
   *       case-spec
   *       case-spec *
   *       [ "default" ":" declaration ";" ]
   *    "}"
   */
  Parser unionBody() =>
      ref<dynamic>(SWITCH) &
      ref<dynamic>(OPEN_PAREN) &
      ref<dynamic>(declaration) &
      ref<dynamic>(CLOSE_PAREN) &
      ref<dynamic>(OPEN_CURLY) &
      unionCaseSpecification().plus() &
      unionDefault().optional() &
      ref<dynamic>(CLOSE_CURLY);

  /*
   * case-spec:
   *   ( "case" value ":")
   *   ( "case" value ":") *
   *   declaration ";"
   */
  Parser unionCaseSpecification() =>
      unionCaseLabel().plus() &
      ref<dynamic>(declaration) &
      ref<dynamic>(SEMICOLON);

  Parser unionCaseLabel() =>
      ref<dynamic>(CASE) & ref<dynamic>(value) & ref<dynamic>(COLON);

  /*
   * [ "default" ":" declaration ";" ]
   */
  Parser unionDefault() =>
      ref<dynamic>(DEFAULT) &
      ref<dynamic>(COLON) &
      ref<dynamic>(declaration) &
      ref<dynamic>(SEMICOLON);

  /* AUXILIARY TYPE SPECIFIERS */

  Parser intTypeSpecifier() =>
      (ref<dynamic>(UNSIGNED).optional() & ref<dynamic>(INT)) |
      ref<dynamic>(UNSIGNED);

  Parser hyperTypeSpecifier() =>
      ref<dynamic>(UNSIGNED).optional() & ref<dynamic>(HYPER);

  Parser floatTypeSpecifier() => ref<dynamic>(FLOAT);

  Parser doubleTypeSpecifier() => ref<dynamic>(DOUBLE);

  Parser quadrupleTypeSpecifier() => ref<dynamic>(QUADRUPLE);

  Parser boolTypeSpecifier() => ref<dynamic>(BOOL);

  Parser stringTypeSpecifier() => ref<dynamic>(STRING);

  Parser voidTypeSpecifier() => ref<dynamic>(VOID);

  Parser cStyleTypeSpecifier() =>
      ref<dynamic>(INT32_T) |
      ref<dynamic>(UINT32_T) |
      ref<dynamic>(INT64_T) |
      ref<dynamic>(UINT64_T);

  /* CONSTANTS */

  // -?[1-9][0-9]+
  Parser decimalConstant() =>
      (char('-').optional() & pattern('1-9') & pattern('0-9').star()).flatten();

  //
  Parser hexadecimalConstant() =>
      string('0x') & ref<dynamic>(hexDigitLexicalToken).plus().flatten() |
      string('0X') & ref<dynamic>(hexDigitLexicalToken).plus().flatten();

  Parser hexDigitLexicalToken() => pattern('0-9a-fA-F');

  //
  Parser octalConstant() => (char('0') & pattern('0-7').star()).flatten();

  // Parser for identifiers
  //Parser identifier() =>
  //    token(letter() & (letter() | digit() | char('_')).star());

  // We wait until parsing to allow better error messages
  Parser identifier() {
    final word = letter() & (letter() | digit() | char('_')).star();
    return word.flatten().trim().where(
          (id) => !keywords.contains(id),
          message: 'Reserved word: $word',
        );
  }

  Parser identifierParser() => letter() & (word() | char('_')).star();

  /* LEXICAL STRUCTURES */
  // ignore: non_constant_identifier_names
  Parser PROGRAM() => token('program');

  // ignore: non_constant_identifier_names
  Parser CONST() => token('const');

  // ignore: non_constant_identifier_names
  Parser VERSION() => token('version');

  // ignore: non_constant_identifier_names
  Parser UNSIGNED() => token('unsigned');

  // ignore: non_constant_identifier_names
  Parser INT() => token('int');

  // ignore: non_constant_identifier_names
  Parser FLOAT() => token('float');

  // ignore: non_constant_identifier_names
  Parser DOUBLE() => token('double');

  // ignore: non_constant_identifier_names
  Parser QUADRUPLE() => token('quadruple');

  // ignore: non_constant_identifier_names
  Parser HYPER() => token('hyper');

  // ignore: non_constant_identifier_names
  Parser BOOL() => token('bool');

  // ignore: non_constant_identifier_names
  Parser VOID() => token('void');

  // ignore: non_constant_identifier_names
  Parser STRING() => token('string');

  // ignore: non_constant_identifier_names
  Parser INT32_T() => token('int32_t');

  // ignore: non_constant_identifier_names
  Parser UINT32_T() => token('uint32_t');

  // ignore: non_constant_identifier_names
  Parser INT64_T() => token('int64_t');

  // ignore: non_constant_identifier_names
  Parser UINT64_T() => token('uint64_t');

  // ignore: non_constant_identifier_names
  Parser TYPEDEF() => token('typedef');

  // ignore: non_constant_identifier_names
  Parser ENUM() => token('enum');

  // ignore: non_constant_identifier_names
  Parser STRUCT() => token('struct');

  // ignore: non_constant_identifier_names
  Parser UNION() => token('union');

  // ignore: non_constant_identifier_names
  Parser SWITCH() => token('switch');

  // ignore: non_constant_identifier_names
  Parser CASE() => token('case');

  // ignore: non_constant_identifier_names
  Parser DEFAULT() => token('default');

  // ignore: non_constant_identifier_names
  Parser OPAQUE() => token('opaque');

  // ignore: non_constant_identifier_names
  Parser OPEN_CURLY() => token('{');

  // ignore: non_constant_identifier_names
  Parser CLOSE_CURLY() => token('}');

  // ignore: non_constant_identifier_names
  Parser OPEN_PAREN() => token('(');

  // ignore: non_constant_identifier_names
  Parser CLOSE_PAREN() => token(')');

  // ignore: non_constant_identifier_names
  Parser OPEN_SQUARE() => token('[');

  // ignore: non_constant_identifier_names
  Parser CLOSE_SQUARE() => token(']');

  // ignore: non_constant_identifier_names
  Parser OPEN_ANGLE() => token('<');

  // ignore: non_constant_identifier_names
  Parser CLOSE_ANGLE() => token('>');

  // ignore: non_constant_identifier_names
  Parser COMMA() => token(',');

  // ignore: non_constant_identifier_names
  Parser STAR() => token('*');

  // ignore: non_constant_identifier_names
  Parser EQUALS() => token('=');

  // ignore: non_constant_identifier_names
  Parser SEMICOLON() => token(';');

  // ignore: non_constant_identifier_names
  Parser COLON() => token(':');

  // ignore: non_constant_identifier_names
  Parser NEWLINE() => pattern('\n\r');

  // Whitespace and comment handling
  Parser space() =>
      whitespace() |
      ref<dynamic>(singleLineComment) |
      ref<dynamic>(multiLineComment);

  Parser singleLineComment() =>
      string('//') &
      ref<dynamic>(NEWLINE).neg().star() &
      ref<dynamic>(NEWLINE).optional();

  Parser multiLineComment() =>
      string('/*') &
      (ref0(multiLineComment) | string('*/').neg()).star() &
      string('*/');

  Parser token(final Object input) {
    if (input is Parser) {
      return input.flatten().trim(ref<dynamic>(space));
    } else if (input is String) {
      return string(input).flatten().trim(ref<dynamic>(space));
    } else {
      throw ArgumentError.value(input, 'parser', 'Invalid parser type');
    }
  }
}
