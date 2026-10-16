import 'package:flutter/services.dart';

/// Android uses java.text.Collator; unsupported hosts fail explicitly.
Future<List<String>> sortPortugueseNames(List<String> names) async {
  final result = await const MethodChannel('br.org.ieadpe/locale')
      .invokeListMethod<String>('sortPortuguese', names);
  if (result == null) throw StateError('Missing locale response');
  return result;
}
