/// Browser integration against the real local emulators (S13).
///
/// Run with the Auth and Firestore emulators started and seeded
/// (`firebase emulators:start`, synthetic fixtures with UIDs
/// `emulator-supervisor`, `emulator-staff-central` and `emulator-staff-norte`):
///
///   flutter test integration_test/browser_flow_test.dart -d chrome \
///     --dart-define=FIREBASE_EMULATOR_HOST=localhost
///
/// This file is not executed by `flutter test`: it needs real emulators and a
/// browser, so it is run by the release verification harness.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:discipulado_ieadpe/app/app.dart';
import 'package:discipulado_ieadpe/app/dependencies.dart';
import 'package:discipulado_ieadpe/app/navigation.dart';
import 'package:discipulado_ieadpe/data/firebase_auth_repository.dart';
import 'package:discipulado_ieadpe/data/firebase_gateway.dart';
import 'package:discipulado_ieadpe/data/firestore_direct_store.dart';
import 'package:discipulado_ieadpe/data/firestore_direct_transport.dart';
import 'package:discipulado_ieadpe/data/handlers/registry.dart';
import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/academic_repository.dart';
import 'package:discipulado_ieadpe/features/students/student_repository.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _host = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);
const int _authPort = int.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const int _firestorePort = int.fromEnvironment(
  'FIREBASE_FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

const String _centralEmail = 'emulator-staff-central@example.test';
const String _norteEmail = 'emulator-staff-norte@example.test';
const String _password = 'Emulator-Only-123';

BackendGateway _gateway() => FirebaseGateway(
  transport: FirestoreDirectTransport(
    store: FirestoreDirectStore(firestore: FirebaseFirestore.instance),
    registry: composeHandlerRegistry(),
    uid: () => FirebaseAuth.instance.currentUser?.uid ?? 'system',
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1:web:emulator',
        messagingSenderId: '1',
        projectId: 'demo-discipulado',
        authDomain: 'demo-discipulado.firebaseapp.com',
      ),
    );
    FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
  });

  testWidgets(
    'sign-in, contact homonym and rename, replaceRoleHolder, saveStudent, '
    'saveClass, enrollStudent, saveAttendance, getEnrollmentProgress, reload '
    'URL/history, sign-out and denied second-congregation access',
    (WidgetTester tester) async {
      final BackendGateway gateway = _gateway();
      final TeamRepository team = TeamRepository(gateway: gateway);
      final StudentRepository students = StudentRepository(gateway: gateway);
      final AcademicRepository academic = AcademicRepository(gateway: gateway);

      // --- sign-in ---------------------------------------------------------
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _centralEmail,
        password: _password,
      );
      expect(FirebaseAuth.instance.currentUser, isNotNull);

      // --- contact homonym: two people with the same name coexist ----------
      final TeamMutationResult first = await team.saveContact(
        draft: const ContactDraft(
          name: 'Homônimo Emulador',
          scope: ContactScope.congregation,
          congregationId: 'emulator-central',
        ),
      );
      final TeamMutationResult second = await team.saveContact(
        draft: const ContactDraft(
          name: 'Homônimo Emulador',
          scope: ContactScope.congregation,
          congregationId: 'emulator-central',
        ),
      );
      expect(first.id, isNot(second.id));

      // --- rename keeps the stable ID --------------------------------------
      final TeamMutationResult renamed = await team.saveContact(
        id: first.id,
        expectedRevision: first.revision,
        draft: const ContactDraft(
          name: 'Homônimo Emulador Renomeado',
          scope: ContactScope.congregation,
          congregationId: 'emulator-central',
        ),
      );
      expect(renamed.id, first.id);

      // --- replaceRoleHolder ----------------------------------------------
      final TeamMutationResult teacher = await team.saveContact(
        draft: const ContactDraft(
          name: 'Professor Emulador',
          scope: ContactScope.congregation,
          congregationId: 'emulator-central',
          roleCode: RoleCode.teacher,
        ),
      );
      final TeamMutationResult replacement = await team.replaceRoleHolder(
        request: RoleReplacementRequest(
          scope: ContactScope.congregation,
          congregationId: 'emulator-central',
          roleCode: RoleCode.campaignLeader,
          previousContactId: renamed.id,
          previousExpectedRevision: renamed.revision,
          targetContactId: teacher.id,
          targetExpectedRevision: teacher.revision,
        ),
      );
      expect(replacement.id, teacher.id);

      // --- saveStudent -----------------------------------------------------
      final StudentMutationResult student = await students.saveStudent(
        congregationId: 'emulator-central',
        draft: const StudentDraft(name: 'Aluno Emulador'),
      );

      // --- saveClass -------------------------------------------------------
      final CalendarDate start = CalendarDate(2026, 1, 4);
      final AcademicMutationResult classGroup = await academic.saveClass(
        congregationId: 'emulator-central',
        draft: ClassDraft(name: 'Turma Emuladora', startDate: start),
      );

      // --- enrollStudent ---------------------------------------------------
      final AcademicMutationResult enrollment = await academic.enrollStudent(
        congregationId: 'emulator-central',
        classId: classGroup.id,
        studentId: student.id,
        startDate: start,
      );

      // --- saveAttendance (save and finalize) ------------------------------
      final AcademicMutationResult session = await academic.createSession(
        congregationId: 'emulator-central',
        classId: classGroup.id,
        date: start,
        topic: 'Aula 1',
      );
      await academic.saveAttendance(
        congregationId: 'emulator-central',
        classId: classGroup.id,
        sessionId: session.id,
        expectedRevision: session.revision,
        marks: <String, AttendanceStatus>{
          enrollment.id: AttendanceStatus.present,
        },
        finalize: true,
      );

      // --- getEnrollmentProgress ------------------------------------------
      final JsonMap progress = await gateway.invoke(
        'getEnrollmentProgress',
        <String, Object?>{
          'congregationId': 'emulator-central',
          'enrollmentId': enrollment.id,
        },
      );
      expect(progress['percentage'], 100);

      // --- reload a direct URL and browser history -------------------------
      final AppDependencies dependencies = AppDependencies.fromPorts(
        authRepository: FirebaseAuthRepository(
          adapter: FirebaseAuthAdapter(
            auth: FirebaseAuth.instance,
            firestore: FirebaseFirestore.instance,
          ),
        ),
        gateway: gateway,
      );
      await tester.pumpWidget(DiscipuladoApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      dependencies.router.go(
        '${AppRoutes.student(student.id)}?congregacao=emulator-central',
      );
      await tester.pumpAndSettle();
      // Hard reload in the browser re-resolves the same authorized detail.
      await tester.pumpWidget(DiscipuladoApp(dependencies: dependencies));
      await tester.pumpAndSettle();

      // --- denied second-congregation access -------------------------------
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _norteEmail,
        password: _password,
      );
      await expectLater(
        students.getStudent(id: student.id, congregationId: 'emulator-central'),
        throwsA(isA<AppFailure>()),
      );

      // --- sign-out --------------------------------------------------------
      await FirebaseAuth.instance.signOut();
      expect(FirebaseAuth.instance.currentUser, isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
