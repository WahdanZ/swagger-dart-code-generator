import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:recase/recase.dart';

abstract class SwaggerModelsGenerator {
  final List<String> _keyClasses = ['Response', 'Request'];

  String generate(String dartCode, String fileName, GeneratorOptions options);

  String getValidatedClassName(String className) {
    final result = className.pascalCase;

    if (_keyClasses.contains(result)) {
      return '$result\$';
    }

    return result;
  }
}
