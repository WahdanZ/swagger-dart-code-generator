import 'dart:convert';
import 'package:swagger_dart_code_generator/src/code_generators/swagger_converter_generator.dart';

class SwaggerConverterGeneratorV3 extends SwaggerConverterGenerator {
  String generateModelsMapping(String dartCode) {
    final dynamic map = jsonDecode(dartCode);

    final definitions = map['components']['schemas'] as Map<String, dynamic>;

    return generateModelsMappingFromMap(dartCode, definitions);
  }
}
