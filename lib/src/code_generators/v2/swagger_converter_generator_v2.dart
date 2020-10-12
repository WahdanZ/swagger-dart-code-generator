import 'dart:convert';
import 'package:swagger_dart_code_generator/src/code_generators/swagger_converter_generator.dart';

class SwaggerConverterGeneratorV2 extends SwaggerConverterGenerator {
  String generateModelsMapping(String dartCode) {
    final dynamic map = jsonDecode(dartCode);

    final definitions = map['definitions'] as Map<String, dynamic>;

    return generateModelsMappingFromMap(dartCode, definitions);
  }
}
