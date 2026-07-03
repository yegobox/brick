import 'dart:typed_data';

/// Turso misinterprets `TYPE NULL` in `ALTER TABLE ADD` as NOT NULL columns.
/// Nullable columns must omit the explicit `NULL` keyword.
String adaptSqlForTurso(String sql) {
  return translateBackticksToDoubleQuotes(
    sql.replaceAllMapped(
      RegExp(
        r'\b(VARCHAR|TEXT|INTEGER|BOOLEAN|BLOB|BIGINT|DOUBLE|FLOAT|DATETIME|DATE)\s+NULL\b',
        caseSensitive: false,
      ),
      (match) => match.group(1)!,
    ),
  );
}

/// libSQL/Turso uses SQL-standard double quotes for identifiers, not MySQL backticks.
String translateBackticksToDoubleQuotes(String sql) {
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;

  for (var i = 0; i < sql.length; i++) {
    final char = sql[i];
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }
    if (!inSingleQuote && !inDoubleQuote && char == '`') {
      buffer.write('"');
      continue;
    }
    buffer.write(char);
  }

  return buffer.toString();
}

String prepareSqlForTurso(String sql) {
  return translateSqlPlaceholders(adaptSqlForTurso(sql));
}

/// Translates sqflite-style `?` placeholders to Turso positional bindings.
String translateSqlPlaceholders(String sql) {
  final buffer = StringBuffer();
  var index = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;

  for (var i = 0; i < sql.length; i++) {
    final char = sql[i];
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }
    if (!inSingleQuote && !inDoubleQuote && char == '?') {
      index += 1;
      buffer.write('?$index');
      continue;
    }
    buffer.write(char);
  }

  return buffer.toString();
}

List<Map<String, Object?>> mapTursoRows(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) {
    return <Map<String, Object?>>[];
  }

  return rows.map((row) {
    if (row.isEmpty) {
      return <String, Object?>{};
    }
    return row.map((key, value) => MapEntry(key, _normalizeValue(value)));
  }).toList();
}

Object? _normalizeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int ||
      value is double ||
      value is String ||
      value is Uint8List) {
    return value;
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  return value;
}
