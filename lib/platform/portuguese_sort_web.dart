import 'dart:js_interop';

@JS('Intl.Collator')
extension type _Collator._(JSObject _) implements JSObject {
  external factory _Collator(JSString locale);
  external JSNumber compare(JSString a, JSString b);
}

Future<List<String>> sortPortugueseNames(List<String> names) async {
  final collator = _Collator('pt-BR'.toJS);
  final indexed = names.indexed.toList();
  indexed.sort((a, b) {
    final order = collator.compare(a.$2.toJS, b.$2.toJS).toDartInt;
    return order == 0 ? a.$1.compareTo(b.$1) : order;
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}
