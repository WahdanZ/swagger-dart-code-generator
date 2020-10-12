import 'package:swagger_dart_code_generator/src/definitions.dart';
import 'package:recase/recase.dart';
import 'package:swagger_dart_code_generator/src/code_generators/v2/swagger_models_generator_v2.dart';

abstract class SwaggerConverterGenerator {
  String _generateModelsMapping(String dartCode);
  String generate(String dartCode, String fileName) {
    return '''
final Map<Type, Object Function(Map<String, dynamic>)> ${fileName.pascalCase}$converterClassEnding = 
{
${_generateModelsMapping(dartCode)}};''';
  }

  String generateModelsMappingFromMap(
      String dartCode, Map<String, dynamic> enums) {
    final result = StringBuffer();

    if (enums == null) {
      return '';
    }

    for (var i = 0; i < enums.keys.length; i++) {
      final key = enums.keys.elementAt(i).toString();

      if (enums[key]['enum'] != null) {
        continue;
      }

      final validatedName =
          SwaggerModelsGeneratorV2().getValidatedClassName(key);

      result.writeln('\t$validatedName: $validatedName.fromJsonFactory,');
    }

    return result.toString();
  }
}
