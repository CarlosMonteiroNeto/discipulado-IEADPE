/// Composition of the direct-transport handler registry (internal mode).
///
/// The registry maps every S11 operation name to exactly one handler; it is
/// what `FirestoreDirectTransport.callFunction` dispatches to, so the feature
/// repositories keep calling the same operations without Cloud Functions.
library;

import '../transport_support.dart';
import 'attendance.dart';
import 'classes.dart';
import 'congregations.dart';
import 'contacts.dart';
import 'enrollments.dart';
import 'overview.dart';
import 'sessions.dart';
import 'students.dart';

/// The full, non-overlapping dispatch table for the direct transport.
///
/// Each slice is authoritative for its own operation names; the composition is
/// a plain map merge, so a duplicate name would surface as the last slice
/// winning. The registry test asserts the set is exact and collision-free.
Map<String, DirectOperationHandler> composeHandlerRegistry() =>
    <String, DirectOperationHandler>{
      ...congregationsHandlers(),
      ...contactsHandlers(),
      ...studentsHandlers(),
      ...classesHandlers(),
      ...enrollmentsHandlers(),
      ...sessionsHandlers(),
      ...attendanceHandlers(),
      ...overviewHandlers(),
    };