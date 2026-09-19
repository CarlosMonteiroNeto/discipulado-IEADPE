/// Application entry point (S01, S11). The executable composition lives in
/// `lib/app/`.
library;

import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrap();
}
