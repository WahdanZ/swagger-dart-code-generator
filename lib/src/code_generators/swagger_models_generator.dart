import 'package:swagger_dart_code_generator/src/code_generators/v3/swagger_enums_generator_v3.dart';
import 'package:swagger_dart_code_generator/src/exception_words.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:recase/recase.dart';
import 'package:swagger_dart_code_generator/src/extensions/string_extension.dart';

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

  String genetateEnumFromJsonToJsonMethods(List<String> enumNames) {
    return enumNames.map((e) => generateEnumFromJsonToJson(e)).join('\n');
  }

  String generateEnumFromJsonToJson(String enumName) {
    final neededName = enumName.replaceFirst('enums.', '');
    return '''
String ${neededName.camelCase}ToJson(enums.$neededName ${neededName.camelCase}) {
  return enums.\$${neededName}Map[${neededName.camelCase}];
}

enums.$neededName ${neededName.camelCase}FromJson(String ${neededName.camelCase}) {
  return enums.\$${neededName}Map.entries
      .firstWhere((element) => element.value == ${neededName.camelCase})
      .key;
}

List<String> ${neededName.camelCase}ListToJson(
    List<enums.$neededName> ${neededName.camelCase}) {
  return ${neededName.camelCase}
      .map((e) => enums.\$${neededName}Map[e])
      .toList();
}

List<enums.$neededName> ${neededName.camelCase}ListFromJson(
    List<String> ${neededName.camelCase}) {
  return ${neededName.camelCase}
      .map((e) => ${neededName.camelCase}FromJson(e))
      .toList();
}
    ''';
  }

  String generateConstructorPropertiesContent(Map<String, dynamic> entityMap) {
    if (entityMap == null) {
      return '';
    }

    final generatedConstructorParameters = entityMap.keys.map((String key) {
      final fieldName = generateFieldName(key);
      return '\t\tthis.$fieldName,';
    }).join('\n');

    return '{\n${generatedConstructorParameters.toString()}\n\t}';
  }

  String generateFieldName(String jsonKey) {
    final forbiddenCharacters = <String>['#'];
    jsonKey = jsonKey.camelCase;

    forbiddenCharacters.forEach((String element) {
      if (jsonKey.startsWith(element)) {
        jsonKey = '\$forbiddenFieldName';
      }
    });

    if (jsonKey.startsWith(RegExp('[0-9]')) ||
        exceptionWords.contains(jsonKey)) {
      jsonKey = '\$' + jsonKey;
    }
    return jsonKey;
  }

  String generateRequestEnumName(
      String path, String requestType, String parameterName) {
    if (path == '/') {
      path = '\$';
    }

    path = path.split('{').map((e) => e.capitalize).join();
    path = path.split('}').map((e) => e.capitalize).join();

    final correctedPath = generateFieldName(path);

    return '${correctedPath.capitalize}${requestType.capitalize}${parameterName.capitalize}';
  }

  String generatePropertiesContent(
      Map<String, dynamic> propertiesMap,
      String className,
      List<DefaultValueMap> defaultValues,
      bool useDefaultNullForLists,
      List<String> allEnumNames) {
    if (propertiesMap == null) {
      return '';
    }

    final results = <String>[];

    for (var i = 0; i < propertiesMap.keys.length; i++) {
      var propertyName = propertiesMap.keys.elementAt(i);
      final propertyEntryMap =
          propertiesMap[propertyName] as Map<String, dynamic>;
      final propertyKey = propertyName;

      exceptionWords.forEach((String exceptionWord) {
        if (propertyName == exceptionWord) {
          propertyName = '\$' + propertyName;
        }
      });

      if (propertyEntryMap.containsKey('type')) {
        results.add(generatePropertyContentByType(
            propertyEntryMap,
            propertyName,
            propertyKey,
            className,
            defaultValues,
            useDefaultNullForLists,
            allEnumNames));
      } else if (propertyEntryMap['\$ref'] != null) {
        results.add(generatePropertyContentByRef(propertyEntryMap, propertyName,
            propertyKey, className, allEnumNames));
      } else if (propertyEntryMap['schema'] != null) {
        results.add(generatePropertyContentBySchema(propertyEntryMap,
            propertyName, propertyKey, className, allEnumNames));
      } else {
        results.add(generatePropertyContentByDefault(
            propertyEntryMap, propertyName, allEnumNames));
      }
    }

    return results.join('\n');
  }

  String generatePropertyContentByType(
      Map<String, dynamic> propertyEntryMap,
      String propertyName,
      String propertyKey,
      String className,
      List<DefaultValueMap> defaultValues,
      bool useDefaultNullForLists,
      List<String> allEnumsNames) {
    switch (propertyEntryMap['type'] as String) {
      case 'array':
        return generateListPropertyContent(propertyName, propertyKey, className,
            propertyEntryMap, useDefaultNullForLists, allEnumsNames);
        break;
      case 'enum':
        return generateEnumPropertyContent(
            propertyName, className, allEnumsNames);
        break;
      default:
        return generateGeneralPropertyContent(propertyName, propertyKey,
            className, defaultValues, propertyEntryMap, allEnumsNames);
    }
  }

  String generatePropertyContentByRef(
      Map<String, dynamic> propertyEntryMap,
      String propertyName,
      String propertyKey,
      String className,
      List<String> allEnumNames) {
    final parameterName = propertyEntryMap['\$ref'].toString().split('/').last;
    var typeName = getParameterTypeName(
        className, propertyName, propertyEntryMap, parameterName);

    final allEnumsNamesWithoutPrefix =
        allEnumNames.map((e) => e.replaceFirst('enums.', '')).toList();

    if (allEnumsNamesWithoutPrefix.contains(typeName)) {
      typeName = 'enums.$typeName';
    }

    final unknownEnumValue =
        generateUnknownEnumValue(allEnumNames, typeName, false);

    final jsonKeyContent = "@JsonKey(name: '$propertyKey'$unknownEnumValue)\n";

    return '\t$jsonKeyContent\tfinal $typeName ${generateFieldName(propertyName)};';
  }

  String generateListPropertyContent(
      String propertyName,
      String propertyKey,
      String className,
      Map<String, dynamic> propertyEntryMap,
      bool useDefaultNullForLists,
      List<String> allEnumNames) {
    final dynamic items = propertyEntryMap['items'];

    String typeName;
    if (items != null) {
      typeName = items['originalRef'] as String;
    }

    typeName ??= getParameterTypeName(
        className, propertyName, items as Map<String, dynamic>);

    final unknownEnumValue =
        generateUnknownEnumValue(allEnumNames, typeName, true);

    final jsonKeyContent =
        "@JsonKey(name: '$propertyKey'${useDefaultNullForLists ? '' : ', defaultValue: <$typeName>[]'}$unknownEnumValue)\n";

    if (allEnumNames.contains(typeName)) {}

    return '''  $jsonKeyContent  final List<$typeName> ${generateFieldName(propertyName)};''';
  }

  String generatePropertyContentBySchema(
      Map<String, dynamic> propertyEntryMap,
      String propertyName,
      String propertyKey,
      String className,
      List<String> allEnumNames) {
    final propertySchema = propertyEntryMap['schema'] as Map<String, dynamic>;
    final parameterName = propertySchema['\$ref'].toString().split('/').last;

    var typeName = getParameterTypeName(
        className, propertyName, propertyEntryMap, parameterName);

    final allEnumsNamesWithoutPrefix =
        allEnumNames.map((e) => e.replaceFirst('enums.', '')).toList();

    if (allEnumsNamesWithoutPrefix.contains(typeName)) {
      typeName = 'enums.$typeName';
    }

    final unknownEnumValue =
        generateUnknownEnumValue(allEnumNames, typeName, false);

    final jsonKeyContent = "@JsonKey(name: '$propertyKey'$unknownEnumValue)\n";

    return '\t$jsonKeyContent\tfinal $typeName ${generateFieldName(propertyName)};';
  }

  String generatePropertyContentByDefault(Map<String, dynamic> propertyEntryMap,
      String propertyName, List<String> allEnumNames) {
    final typeName = propertyEntryMap['originalRef'] ?? 'dynamic';

    final unknownEnumValue =
        generateUnknownEnumValue(allEnumNames, typeName.toString(), false);

    final jsonKeyContent = "@JsonKey(name: '$propertyName'$unknownEnumValue)\n";
    return '\t$jsonKeyContent\tfinal $typeName ${generateFieldName(propertyName)};';
  }

  String generateUnknownEnumValue(
      List<String> allEnumNames, String typeName, bool isList) {
    var unknownEnumValue = allEnumNames.contains(typeName)
        ? ', unknownEnumValue: $typeName.swaggerGeneratedUnknown'
        : '';

    if (unknownEnumValue.isNotEmpty) {
      if (!isList) {
        final enumNameCamelCase = typeName.replaceAll('enums.', '').camelCase;
        final toJsonFromJson =
            ', toJson: ${enumNameCamelCase}ToJson, fromJson: ${enumNameCamelCase}FromJson';

        unknownEnumValue += toJsonFromJson;
      } else {
        final enumNameCamelCase = typeName.replaceAll('enums.', '').camelCase;
        final toJsonFromJson =
            ', toJson: ${enumNameCamelCase}ListToJson, fromJson: ${enumNameCamelCase}ListFromJson';

        unknownEnumValue += toJsonFromJson;
      }
    }

    return unknownEnumValue;
  }

  String getParameterTypeName(
      String className, String parameterName, Map<String, dynamic> parameter,
      [String nameParameter]) {
    if (nameParameter != null) {
      return nameParameter.pascalCase;
    }

    if (parameter == null) {
      return 'Object';
    }

    if (parameter['\$ref'] != null) {
      return parameter['\$ref'].toString().split('/').last.pascalCase;
    }

    switch (parameter['type'] as String) {
      case 'integer':
        return 'int';
      case 'boolean':
        return 'bool';
      case 'string':
        if (parameter['format'] == 'date-time' ||
            parameter['format'] == 'date') {
          return 'DateTime';
        } else if (parameter['enum'] != null) {
          return SwaggerEnumsGeneratorV3()
              .generateEnumName(className, parameterName);
        }
        return 'String';
      case 'number':
        return 'double';
      case 'object':
        return 'Object';
      case 'array':
        final items = parameter['items'] as Map<String, dynamic>;
        return getParameterTypeName(className, parameterName, items);
      default:
        if (parameter['oneOf'] != null) {
          return 'Object';
        }
        return 'undefinedType';
    }
  }

  String generateEnumPropertyContent(
      String key, String className, List<String> allEnumNames) {
    final enumName = SwaggerEnumsGeneratorV3().generateEnumName(className, key);

    allEnumNames.add(enumName);

    final unknownEnumValue =
        generateUnknownEnumValue(allEnumNames, enumName, false);
    return '''
  @JsonKey($unknownEnumValue)
  final ${className.capitalize + key.capitalize} ${generateFieldName(key)};''';
  }

  String generateGeneralPropertyContent(
      String propertyName,
      String propertyKey,
      String className,
      List<DefaultValueMap> defaultValues,
      Map<String, dynamic> val,
      List<String> allEnumNames) {
    var jsonKeyContent = "@JsonKey(name: '$propertyKey'";
    var typeName = getParameterTypeName(className, propertyName, val);

    final allEnumsNamesWithoutPrefix =
        allEnumNames.map((e) => e.replaceFirst('enums.', '')).toList();

    if (allEnumsNamesWithoutPrefix.contains(typeName)) {
      typeName = 'enums.$typeName';
    }

    final unknownEnumValue =
        generateUnknownEnumValue(allEnumNames, typeName, false);

    jsonKeyContent += unknownEnumValue;

    if (defaultValues
        .any((DefaultValueMap element) => element.typeName == typeName)) {
      final defaultValue = defaultValues.firstWhere(
          (DefaultValueMap element) => element.typeName == typeName);
      jsonKeyContent +=
          ', defaultValue: ${generateDefaultValueFromMap(defaultValue)}';
    }
    return '''  $jsonKeyContent)\n  final $typeName ${generateFieldName(propertyName)};''';
  }

  String generateDefaultValueFromMap(DefaultValueMap map) {
    switch (map.typeName) {
      case 'int':
      case 'double':
      case 'bool':
        return map.defaultValue;
      default:
        return "'${map.defaultValue}'";
    }
  }
}
