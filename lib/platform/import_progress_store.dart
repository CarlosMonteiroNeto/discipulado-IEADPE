import '../features/backup/backup_repository.dart';
import 'import_progress_store_native.dart'
    if (dart.library.js_interop) 'import_progress_store_web.dart'
    as platform;

ImportProgressStore createImportProgressStore() =>
    platform.PlatformImportProgressStore();
