import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/photos/photo_crop.dart';

import '../../support/date_picker.dart';
import 'save_test.dart' show TestGateway;

const _congregationId = 'b0000000-0000-4000-8000-000000000001';

ConvertRecord record({
  String worship = '01 - Oração',
  String name = 'Pessoa',
  String? congregationId = _congregationId,
  String? personId,
  int? personRevision,
  CanonicalPersonIdentity? personIdentity,
  String? address,
}) => ConvertRecord(
  id: 'id',
  internalId: 'legacy',
  name: name,
  landmark: 'Praça',
  gender: Gender.male,
  conversionDate: DateOnly(2026, 1, 1),
  worshipType: worship,
  age: 0,
  congregationId: congregationId,
  personId: personId,
  personRevision: personRevision,
  personIdentity: personIdentity,
  address: address,
);
Widget host(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);
Future<void> tapSave(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.tap(find.text(text));
  await t.pump();
}

void main() {
  testWidgets('blank required fields explain validation in Portuguese', (
    t,
  ) async {
    await t.pumpWidget(host(ConvertForm(onSubmit: (_) async {})));
    await tapSave(t, 'Cadastrar');
    expect(find.text('Nome é obrigatório'), findsOneWidget);
    expect(find.text('Ponto de referência é obrigatório'), findsOneWidget);
  });
  testWidgets('photo upload failure does not claim that access changed', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          onSubmit: (_) async => throw const DataFailure('photo_upload'),
        ),
      ),
    );
    await tapSave(t, 'Atualizar');
    expect(
      find.text(
        'Não foi possível enviar a foto. Seus dados foram mantidos. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Seu acesso mudou'), findsNothing);
  });
  testWidgets(
    'age zero, optional nulls and legacy worship round trip; double press submits once',
    (t) async {
      final pending = Completer<void>();
      final drafts = <ConvertDraft>[];
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(worship: 'Culto legado'),
            onSubmit: (d) {
              drafts.add(d);
              return pending.future;
            },
          ),
        ),
      );
      await tapSave(t, 'Atualizar');
      expect(drafts.single.age, 0);
      expect(drafts.single.phone, null);
      expect(drafts.single.congregationId, _congregationId);
      expect(drafts.single.worshipType, 'Culto legado');
      await t.tap(find.text('Salvando…'));
      await t.pump();
      expect(drafts.length, 1);
      pending.complete();
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'unchanged null canonical address stays null for an inherited long name',
    (t) async {
      final name = List.filled(244, 'A').join();
      ConvertDraft? saved;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(
              name: name,
              congregationId: _congregationId,
              personId: 'person',
              personRevision: 7,
              personIdentity: CanonicalPersonIdentity(name: name),
            ),
            onSubmit: (draft) async => saved = draft,
          ),
        ),
      );

      await tapSave(t, 'Atualizar');

      expect(saved!.name, name);
      expect((saved!.payload()['person'] as Map)['address'], isNull);
    },
  );
  testWidgets(
    'edited canonical address fields remain a complete address object',
    (t) async {
      ConvertDraft? saved;
      const name = 'Pessoa';
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(
              name: name,
              congregationId: _congregationId,
              personId: 'person',
              personRevision: 1,
              personIdentity: const CanonicalPersonIdentity(name: name),
            ),
            onSubmit: (draft) async => saved = draft,
          ),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('person-address-street')),
        'Rua Nova',
      );
      await t.enterText(
        find.byKey(const ValueKey('person-address-city')),
        'Recife',
      );

      await tapSave(t, 'Atualizar');

      expect((saved!.payload()['person'] as Map)['address'], {
        'street': 'Rua Nova',
        'district': null,
        'city': 'Recife',
        'postal_code': null,
        'state_code': null,
      });
    },
  );
  testWidgets(
    'cancelling photo picker retains fields and does not request removal',
    (t) async {
      ConvertDraft? saved;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(),
            allowPhotos: true,
            photoAuthority: (_) => true,
            pickPhoto: () async => null,
            onSubmit: (d) async {
              saved = d;
            },
          ),
        ),
      );
      await t.tap(find.text('Escolher foto'));
      await t.pumpAndSettle();
      await tapSave(t, 'Atualizar');
      expect(saved!.name, 'Pessoa');
      expect(saved!.photoBytes, null);
      expect(saved!.removePhoto, false);
    },
  );
  testWidgets('photo authority is revalidated before opening the picker', (
    t,
  ) async {
    var pickerCalls = 0;
    var revocations = 0;
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          allowPhotos: true,
          photoAuthority: (_) => true,
          revalidatePhotoAuthority: (_) async => false,
          onPhotoAuthorityRevoked: () => revocations++,
          pickPhoto: () async {
            pickerCalls++;
            return Uint8List.fromList([1]);
          },
          onSubmit: (_) async {},
        ),
      ),
    );
    await t.tap(find.text('Escolher foto'));
    await t.pumpAndSettle();

    expect(pickerCalls, 0);
    expect(revocations, 1);
    expect(
      find.text('Seu acesso mudou. Atualize a página antes de enviar fotos.'),
      findsOneWidget,
    );
  });
  testWidgets('scope change clears selected photo bytes and removal state', (
    t,
  ) async {
    final oldPhoto = Uint8List.fromList([1]);
    var revocations = 0;
    ConvertDraft? submitted;

    Widget buildForm({required bool authorized}) {
      final authorityAtBuild = authorized;
      return host(
        ConvertForm(
          initial: record(),
          allowPhotos: true,
          photoAuthority: (_) => authorityAtBuild,
          existingPhoto: oldPhoto,
          pickPhoto: () async => Uint8List.fromList([2]),
          onPhotoAuthorityRevoked: () => revocations++,
          onSubmit: (draft) async => submitted = draft,
        ),
      );
    }

    await t.pumpWidget(buildForm(authorized: true));
    await t.tap(find.text('Escolher foto'));
    await t.pumpAndSettle();
    expect(
      find.text('Nova foto selecionada. A foto atual será mantida até salvar.'),
      findsOneWidget,
    );

    await t.pumpWidget(buildForm(authorized: false));
    expect(revocations, 1);
    expect(find.text('Escolher foto'), findsNothing);
    await tapSave(t, 'Atualizar');
    expect(submitted!.photoBytes, isNull);
    expect(submitted!.removePhoto, isFalse);
  });
  testWidgets('camera selection stores original bytes with confirmed crop', (
    t,
  ) async {
    ConvertDraft? submitted;
    ImageSource? selectedSource;
    List<int>? cropInput;
    const original = [255, 216, 1, 2];
    final currentPhoto = Uint8List.fromList([255, 216, 9, 9]);
    final crop = NormalizedPhotoCrop(left: .5, top: 0, size: 1);
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          allowPhotos: true,
          photoAuthority: (_) => true,
          existingPhoto: currentPhoto,
          choosePhotoSource: (_) async => ImageSource.camera,
          acquirePhoto: (source) async {
            selectedSource = source;
            return Uint8List.fromList(original);
          },
          cropPhoto: (_, source) async {
            cropInput = source.toList();
            return crop;
          },
          onSubmit: (draft) async => submitted = draft,
        ),
      ),
    );

    await t.tap(find.text('Escolher foto'));
    await t.pumpAndSettle();
    final preview = t.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(preview.bytes, currentPhoto);
    await tapSave(t, 'Atualizar');

    expect(selectedSource, ImageSource.camera);
    expect(cropInput, original);
    expect(submitted!.photoBytes, original);
    expect(submitted!.photoCrop, crop);
  });

  testWidgets(
    'authority is revalidated after source choice before acquisition',
    (t) async {
      var revalidations = 0;
      var acquisitions = 0;
      var cropCalls = 0;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(),
            allowPhotos: true,
            photoAuthority: (_) => true,
            choosePhotoSource: (_) async => ImageSource.gallery,
            revalidatePhotoAuthority: (_) async => ++revalidations == 1,
            acquirePhoto: (_) async {
              acquisitions++;
              return Uint8List.fromList([255, 216, 1, 2]);
            },
            cropPhoto: (_, _) async {
              cropCalls++;
              return NormalizedPhotoCrop(left: .25, top: 0, size: 1);
            },
            onSubmit: (_) async {},
          ),
        ),
      );

      await t.tap(find.text('Escolher foto'));
      await t.pumpAndSettle();

      expect(revalidations, 2);
      expect(acquisitions, 0);
      expect(cropCalls, 0);
      expect(
        find.text('Seu acesso mudou. Atualize a página antes de enviar fotos.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('canceling crop keeps the previous photo and form values', (
    t,
  ) async {
    final previous = Uint8List.fromList([255, 216, 9, 9]);
    ConvertDraft? submitted;
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          allowPhotos: true,
          photoAuthority: (_) => true,
          existingPhoto: previous,
          choosePhotoSource: (_) async => ImageSource.gallery,
          acquirePhoto: (_) async => Uint8List.fromList([255, 216, 1, 2]),
          cropPhoto: (_, _) async => null,
          onSubmit: (draft) async => submitted = draft,
        ),
      ),
    );

    await t.tap(find.text('Escolher foto'));
    await t.pumpAndSettle();
    await tapSave(t, 'Atualizar');

    expect(submitted!.photoBytes, isNull);
    expect(submitted!.photoCrop, isNull);
    expect(submitted!.removePhoto, isFalse);
    expect(find.text('Remover foto'), findsOneWidget);
  });

  testWidgets('scope loss while crop is open cannot publish selected bytes', (
    t,
  ) async {
    var authorized = true;
    ConvertDraft? submitted;
    final previous = Uint8List.fromList([255, 216, 9, 9]);
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          allowPhotos: true,
          photoAuthority: (_) => authorized,
          existingPhoto: previous,
          choosePhotoSource: (_) async => ImageSource.camera,
          acquirePhoto: (_) async => Uint8List.fromList([255, 216, 1, 2]),
          revalidatePhotoAuthority: (_) async => true,
          cropPhoto: (_, _) async {
            authorized = false;
            return NormalizedPhotoCrop(left: .25, top: 0, size: 1);
          },
          onSubmit: (draft) async => submitted = draft,
        ),
      ),
    );

    await t.tap(find.text('Escolher foto'));
    await t.pumpAndSettle();
    await tapSave(t, 'Atualizar');

    expect(submitted!.photoBytes, isNull);
    expect(submitted!.photoCrop, isNull);
    expect(submitted!.removePhoto, isFalse);
  });

  testWidgets('session invalidation during crop does not publish bytes', (
    t,
  ) async {
    final gateway = TestGateway();
    var submits = 0;
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          allowPhotos: true,
          gateway: gateway,
          photoAuthority: (_) => true,
          choosePhotoSource: (_) async => ImageSource.camera,
          acquirePhoto: (_) async => Uint8List.fromList([255, 216, 1, 2]),
          revalidatePhotoAuthority: (_) async => true,
          cropPhoto: (_, _) async {
            gateway.boundary.invalidate();
            return NormalizedPhotoCrop(left: .25, top: 0, size: 1);
          },
          onSubmit: (_) async => submits++,
        ),
      ),
    );

    await t.tap(find.text('Escolher foto'));
    await t.pumpAndSettle();

    expect(
      find.text('Nova foto selecionada. A foto atual será mantida até salvar.'),
      findsNothing,
    );
    expect(submits, 0);
  });
  testWidgets(
    'future date uses Sao Paulo business today and keeps draft on failure',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(),
            now: () => DateTime.utc(2026, 1, 2, 1),
            onSubmit: (d) async {
              calls++;
              throw Exception('secret SQL');
            },
          ),
        ),
      );
      await pickDate(
        t,
        const ValueKey('conversion_date'),
        DateTime(2026, 1, 2),
      );
      await tapSave(t, 'Atualizar');
      expect(calls, 0);
      expect(find.text('A data não pode ser futura'), findsOneWidget);
      await pickDate(
        t,
        const ValueKey('conversion_date'),
        DateTime(2026, 1, 1),
      );
      await tapSave(t, 'Atualizar');
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Seus dados foram mantidos'), findsOneWidget);
      expect(find.textContaining('secret SQL'), findsNothing);
    },
  );
  testWidgets(
    'form fits 360 pixels at 200 percent with reduced motion and keyboard',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(worship: worshipTypes[42]),
            onSubmit: (_) async {},
          ),
          scale: 2,
        ),
      );
      await t.ensureVisible(find.byKey(const ValueKey('person-phone')));
      await t.tap(find.byKey(const ValueKey('person-phone')));
      await t.pump();
      await t.ensureVisible(find.text('Atualizar'));
      await t.pump();
      expect(t.takeException(), null);
    },
  );
  test('source worship choices preserve all 64 exact wire labels', () {
    expect(worshipTypes.length, 64);
    expect(worshipTypes.first, '01 - Oração');
    expect(worshipTypes.last, '64 - Inauguração de Templo');
  });
}
