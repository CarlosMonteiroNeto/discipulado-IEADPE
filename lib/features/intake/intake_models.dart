import '../converts/convert_form.dart';

/// Canonical public payload built only from the existing form draft.
final class PublicIntakeDraft {
  PublicIntakeDraft._(this._value);

  final Map<String, Object?> _value;

  factory PublicIntakeDraft.fromConvertDraft(ConvertDraft draft) {
    if (draft.photoBytes != null || draft.removePhoto) {
      throw ArgumentError('Public intake cannot include a photo');
    }
    if (draft.congregationId == null || draft.congregationId!.isEmpty) {
      throw ArgumentError('Public intake requires a congregation');
    }
    final source = draft.payload();
    final person = Map<String, Object?>.from(source['person']! as Map);
    final convert = Map<String, Object?>.from(source['convert']! as Map)
      ..remove('photo_asset_id');
    return PublicIntakeDraft._(
      Map<String, Object?>.unmodifiable({
        'congregation_id': source['congregation_id'],
        'person': Map<String, Object?>.unmodifiable(person),
        'convert': Map<String, Object?>.unmodifiable(convert),
      }),
    );
  }

  Map<String, Object?> toJson() => _value;
}
