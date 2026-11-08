import '../../domain/services/export_service.dart';
import 'export_file_dispatcher_stub.dart'
    if (dart.library.io) 'export_file_dispatcher_io.dart'
    if (dart.library.js_interop) 'export_file_dispatcher_web.dart';

/// Platform-aware dispatcher that shares exported files via `share_plus` on
/// Android/iOS or triggers a native browser file download on Web.
class ExportFileDispatcher {
  const ExportFileDispatcher();

  Future<void> dispatch(GeneratedExportDocument document) {
    return dispatchPlatformExportDocument(document);
  }
}
