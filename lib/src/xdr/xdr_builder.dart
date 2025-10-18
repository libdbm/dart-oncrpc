// lib/xdr_builder.dart
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'xdr_generator.dart';

Builder xdrBuilder(final BuilderOptions options) =>
    SharedPartBuilder([XdrGenerator()], 'xdr');
