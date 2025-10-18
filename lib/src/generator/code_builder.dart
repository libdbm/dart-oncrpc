/// Helper class for building formatted code with proper indentation
class CodeBuilder {
  CodeBuilder({final String indentUnit = '  '}) : _indentUnit = indentUnit;
  final StringBuffer _buffer = StringBuffer();
  String _indent = '';
  final String _indentUnit;
  final Set<String> _imports = {};

  /// Add an import statement
  void addImport(final String import) {
    _imports.add(import);
  }

  /// Write imports to the buffer
  void writeImports() {
    if (_imports.isNotEmpty) {
      final sorted = _imports.toList()..sort();
      _buffer
        ..writeAll(sorted.map((final import) => '$import\n'))
        ..writeln();
    }
  }

  /// Write a line with current indentation
  void writeln([final String line = '']) {
    if (line.isEmpty) {
      _buffer.writeln();
    } else {
      _buffer.writeln('$_indent$line');
    }
  }

  /// Write text without adding newline (maintains current indentation context)
  void write(final String text) {
    // If text contains newlines, process each line with proper indentation
    if (text.contains('\n')) {
      final lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) {
          _buffer.writeln();
        }
        if (lines[i].isNotEmpty) {
          _buffer.write(lines[i]);
        }
      }
    } else {
      _buffer.write(text);
    }
  }

  /// Increase indentation level
  void indent() {
    _indent += _indentUnit;
  }

  /// Decrease indentation level
  void dedent() {
    if (_indent.length >= _indentUnit.length) {
      _indent = _indent.substring(0, _indent.length - _indentUnit.length);
    }
  }

  /// Execute block with increased indentation
  void indented(final void Function() block) {
    indent();
    block();
    dedent();
  }

  /// Write a comment line
  void comment(final String text) {
    writeln('// $text');
  }

  /// Write a doc comment line
  void doc(final String text) {
    writeln('/// $text');
  }

  /// Write a block of code (curly braces with proper indentation)
  void block(final String header, final void Function() body) {
    writeln('$header {');
    indented(body);
    writeln('}');
  }

  /// Clear the buffer
  void clear() {
    _buffer.clear();
    _imports.clear();
  }

  /// Get the generated code as a string
  @override
  String toString() => _buffer.toString();

  /// Get the generated code with imports
  String toStringWithImports() {
    final result = StringBuffer();
    if (_imports.isNotEmpty) {
      final sorted = _imports.toList()..sort();
      result
        ..writeAll(sorted.map((final import) => '$import\n'))
        ..writeln();
    }
    result.write(_buffer.toString());
    return result.toString();
  }
}
