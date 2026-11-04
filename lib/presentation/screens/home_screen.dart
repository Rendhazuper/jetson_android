import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../core/config/app_config.dart';
import '../../core/face/camera_utils.dart';
import '../../core/face/face_preprocessor.dart';
import '../../core/face/face_recognizer.dart';
import '../../data/attendance_service.dart';
import '../../data/daily_log_entry.dart';
import '../../data/person_api_service.dart';
import '../widgets/attendance_log_tile.dart';
import '../widgets/attendance_success_dialog.dart';
import '../widgets/camera_frame_overlay.dart';
import '../widgets/header_clock.dart';
import '../widgets/indonesian_date.dart';

/// Layar utama presensi wajah — padanan dari `FaceRecognitionWindow` di `app_tkinter.py`.
/// Desain visual mengikuti Image 1: Header UNEJ gelap, Card Kamera responsif,
/// panel informasi dan log presensi harian dengan badge warna ID (biru) & Nama (oranye).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  late final FaceDetector _faceDetector;
  final AttendanceService _attendanceService = AttendanceService(
    cooldownSeconds: AppConfig.attendanceCooldownSeconds,
  );
  final PersonApiService _apiService = PersonApiService();

  bool _isProcessingFrame = false;
  DateTime _lastProcessTime = DateTime.now();

  // Status & Event State
  String _status = 'Menginisialisasi kamera...';
  String _eventTitle = 'MENUNGGU PENGENALAN';
  Color _eventColor = const Color(0xFF2563EB);
  String _eventMessage = 'Menunggu wajah terdeteksi.';

  // Information Panel State
  String _nama = '-';
  String _nomorPegawai = '-';
  String _unitKerja = '-';
  double _confidenceValue = 0;
  String _waktu = '-';

  // Log Harian
  final List<DailyLogEntry> _dailyLog = [];
  bool _isSuccessDialogOpen = false;

  // Palet UPATIK
  static const _green = Color(0xFF2FA23A);
  static const _greenDark = Color(0xFF1F7F2B);
  static const _pageBackground = Color(0xFFE8EBEE);
  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _status = 'Kamera tidak ditemukan');
        return;
      }

      // Default gunakan kamera depan bila ada (front-facing)
      final frontIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _cameraIndex = frontIdx != -1 ? frontIdx : 0;

      await _startCamera();
    } catch (e) {
      setState(() => _status = 'Gagal inisialisasi kamera: $e');
    }
  }

  Future<void> _startCamera() async {
    final camera = _cameras[_cameraIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() => _status = 'Kamera aktif (${camera.lensDirection.name})');

      await controller.startImageStream(_processCameraFrame);
    } catch (e) {
      setState(() => _status = 'Gagal membuka kamera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
      _cameraController = null;
      setState(() => _status = 'Kamera dihentikan');
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame) return;

    // Batasi ~10 FPS untuk menjaga efisiensi suhu dan baterai
    final now = DateTime.now();
    if (now.difference(_lastProcessTime).inMilliseconds < 100) return;

    _isProcessingFrame = true;
    _lastProcessTime = now;

    try {
      final camera = _cameras[_cameraIndex];
      final rotation = CameraUtils.rotationDegrees(
        camera: camera,
        deviceOrientation: _cameraController!.value.deviceOrientation,
      );
      final inputImage = CameraUtils.inputImageFromCameraImage(
        image: image,
        rotationDegrees: rotation,
      );

      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      debugPrint('[FACE DETECT] Faces count: ${faces.length}');

      if (!mounted) return;

      if (faces.isEmpty) {
        FaceRecognizer.instance.resetVotes();
        return;
      }

      // Ambil wajah terbesar
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final primaryFace = faces.first;

      // 1. Luruskan wajah ke template SFace dari 5 landmark ML Kit, langsung
      //    dari buffer kamera dengan rotasi yang benar. Tanpa landmark lengkap
      //    frame dilewati: crop bounding box tidak cocok dengan gallery.
      final landmarks = CameraUtils.sfaceLandmarks(primaryFace);
      if (landmarks == null) {
        FaceRecognizer.instance.resetVotes();
        return;
      }

      final faceImage = CameraUtils.alignFaceRotated(
        image: image,
        landmarks: landmarks,
        rotation: rotation,
      );

      // 2. Preprocessing (CLAHE kanal L + NCHW Float32)
      final nchwFloats = FacePreprocessor.processCroppedFace(faceImage);

      // 3. Rekognisi via SFace ONNX
      final result = FaceRecognizer.instance.recognize(nchwFloats);

      // Berisi ID personal: hanya dicatat pada build debug.
      if (kDebugMode) {
        debugPrint(
          '[RECOG] bestDistance=${result?.distance.toStringAsFixed(3)} '
          'threshold=${result?.threshold} '
          'name=${result?.name} '
          'closest=${result?.closestName}',
        );
      }

      if (result != null && result.isPending) {
        setState(() {
          _eventTitle = 'MEMVERIFIKASI';
          _eventColor = const Color(0xFF2563EB);
          _eventMessage = 'Memverifikasi wajah, tahan sebentar...';
          _confidenceValue = result.confidence;
        });
        return;
      }

      if (result == null || result.name == null) {
        setState(() {
          _eventTitle = 'UNKNOWN';
          _eventColor = const Color(0xFFDC2626);
          _confidenceValue = 0;
          _eventMessage =
              'Wajah tidak cocok (dist: ${result?.distance.toStringAsFixed(3) ?? '-'})';
        });
        return;
      }

      final recognizedId = result.name!;

      // ID personal bersifat rahasia: jangan tampil di UI sebelum (dan
      // sesudah) server mengonfirmasi. Identitas hanya dari balasan API.
      setState(() {
        _eventTitle = 'TERDETEKSI';
        _eventColor = const Color(0xFF16A34A);
        _eventMessage = 'Wajah dikenali, memproses presensi...';
        _confidenceValue = result.confidence;
      });

      // 4. Cooldown perorangan (gate 30 detik)
      if (_attendanceService.canAttend(recognizedId)) {
        _handleAttendance(recognizedId, result.confidence);
      }
    } catch (e, st) {
      debugPrint('[PREVIEW ERROR] $e\n$st');
      if (mounted) {
        setState(() {
          _eventTitle = 'ERROR PIPELINE';
          _eventColor = const Color(0xFFDC2626);
          _eventMessage = 'Error: $e';
        });
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _handleAttendance(String personId, double confidence) async {
    setState(() {
      _eventTitle = 'MENGIRIM PRESENSI...';
      _eventColor = const Color(0xFF2563EB);
      _eventMessage = 'Mengirim identifikasi ke server...';
    });

    final apiRes = await _apiService.sendPersonId(personId);
    if (!mounted) return;

    final timeStr = DateTime.now().toString().substring(11, 19);
    final streams = apiRes.data?['streams'] as Map<String, dynamic>?;

    final namaStr = streams?['nama']?.toString() ?? '-';
    final nipStr = streams?['nomorpegawai']?.toString() ?? '-';
    final unitStr = streams?['nama_unit_kerja']?.toString() ?? '-';
    // Utamakan waktu dari server; jatuh ke jam perangkat bila format tak dikenali.
    final waktu =
        DateTime.tryParse(streams?['waktu']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final waktuStr =
        '${IndonesianDate.time(waktu, separator: '.')} '
        '${IndonesianDate.zone(waktu.timeZoneOffset)}';

    setState(() {
      if (apiRes.ok) {
        _eventTitle = 'BERHASIL';
        _eventColor = const Color(0xFF16A34A);
        _eventMessage = apiRes.message;

        _nama = namaStr;
        _nomorPegawai = nipStr;
        _unitKerja = unitStr;
        _waktu = waktuStr;

        _dailyLog.insert(
          0,
          DailyLogEntry(
            time: timeStr,
            idPegawai: nipStr,
            nama: namaStr,
            status: 'Berhasil',
          ),
        );
      } else {
        _eventTitle = 'GAGAL API';
        _eventColor = const Color(0xFFDC2626);
        _eventMessage = apiRes.message;

        _dailyLog.insert(
          0,
          DailyLogEntry(
            time: timeStr,
            idPegawai: '-',
            nama: 'Presensi gagal',
            status: 'Gagal',
            message: apiRes.message,
          ),
        );
      }
    });

    if (apiRes.ok) {
      _showAttendanceSuccessDialog(
        nama: namaStr == '-' ? 'Presensi Anda telah tercatat' : namaStr,
        waktu: waktu,
      );
    }
  }

  /// Pop-up presensi berhasil. Tidak menumpuk: bila satu masih terbuka,
  /// presensi berikutnya hanya masuk ke log.
  Future<void> _showAttendanceSuccessDialog({
    required String nama,
    required DateTime waktu,
  }) async {
    if (!mounted || _isSuccessDialogOpen) return;
    _isSuccessDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => AttendanceSuccessDialog(nama: nama, waktu: waktu),
    );
    _isSuccessDialogOpen = false;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    FaceRecognizer.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isLandscape ? _buildLandscapeBody() : _buildPortraitBody(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Landscape: hasil + status di kiri, kamera di tengah, log di kanan.
  Widget _buildLandscapeBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 26, child: _buildLeftColumn()),
        const SizedBox(width: 12),
        Expanded(flex: 48, child: _buildCenterColumn()),
        const SizedBox(width: 12),
        Expanded(flex: 26, child: _buildLogCard()),
      ],
    );
  }

  // Portrait: kamera di atas, hasil dan log berdampingan di bawah.
  Widget _buildPortraitBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: _buildCenterColumn()),
        const SizedBox(height: 12),
        Expanded(
          flex: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildLeftColumn()),
              const SizedBox(width: 12),
              Expanded(child: _buildLogCard()),
            ],
          ),
        ),
      ],
    );
  }

  // ===== HEADER =====
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_greenDark, _green]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Image.asset(
            AppConfig.logoAsset,
            width: 46,
            height: 46,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.school, color: Colors.amber, size: 42),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VISION UNEJ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Visual Identification & Smart Integrated Online Network',
                style: TextStyle(color: Color(0xFFE5F5E7), fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UPATIK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              HeaderClock(),
            ],
          ),
        ],
      ),
    );
  }

  // ===== FOOTER =====
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'Copyright © ${DateTime.now().year} UPA Teknologi Informasi dan '
        'Komunikasi Universitas Jember',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  // ===== KARTU UMUM =====
  Widget _card({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ===== KOLOM KIRI: HASIL PRESENSI + STATUS =====
  Widget _buildLeftColumn() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            title: 'Hasil Presensi',
            child: Column(
              children: [
                _infoRow(Icons.person, _nama, bold: true),
                _infoRow(Icons.badge_outlined, _nomorPegawai),
                _infoRow(Icons.apartment, _unitKerja),
                _infoRow(Icons.schedule, _waktu),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(title: 'Status', child: _buildStatusContent()),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 19, color: _green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLabel => switch (_eventTitle) {
    'BERHASIL' => 'Berhasil',
    'TERDETEKSI' => 'Terdeteksi',
    'MEMVERIFIKASI' => 'Memverifikasi',
    'MENGIRIM PRESENSI...' => 'Mengirim',
    'UNKNOWN' => 'Tidak Dikenal',
    'GAGAL API' => 'Gagal',
    'ERROR PIPELINE' => 'Error',
    _ => 'Menunggu',
  };

  Widget _buildStatusContent() {
    final percent = _confidenceValue > 0
        ? '${(_confidenceValue * 100).toStringAsFixed(1)}%'
        : '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: _eventColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _statusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Confidence',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const Spacer(),
            Text(
              percent,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _confidenceValue.clamp(0.0, 1.0),
            minHeight: 8,
            color: _green,
            backgroundColor: const Color(0xFFE5E7EB),
          ),
        ),
      ],
    );
  }

  // ===== KOLOM TENGAH: KAMERA + BANNER STATUS =====
  Widget _buildCenterColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildCameraCard()),
        const SizedBox(height: 10),
        _buildStatusBanner(),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final text = _eventTitle == 'BERHASIL'
        ? 'Presensi Vision Berhasil'
        : _eventMessage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _eventColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ===== KAMERA (cover tanpa distorsi) + bingkai =====
  Widget _buildCameraCard() {
    final controller = _cameraController;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF05080D),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _buildCameraPreview(controller)
          else
            const Center(
              child: Text(
                'Memuat kamera...',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ),
          const CameraFrameOverlay(color: _green),
          Positioned(left: 18, top: 18, child: _cameraChip(_status)),
          Positioned(right: 14, top: 14, child: _buildCameraControls()),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Pada Android portrait, dimensi sensor ditukar (tinggi jadi lebar dan sebaliknya)
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final double previewWidth = isPortrait
            ? previewSize.height
            : previewSize.width;
        final double previewHeight = isPortrait
            ? previewSize.width
            : previewSize.height;

        final previewAspect = previewWidth / previewHeight;
        final containerAspect = constraints.maxWidth / constraints.maxHeight;

        // Hitung skala cover tanpa distorsi
        final double scale = containerAspect > previewAspect
            ? containerAspect / previewAspect
            : previewAspect / containerAspect;

        return ClipRect(
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: AspectRatio(
                aspectRatio: previewAspect,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cameraChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildCameraControls() {
    final running = _cameraController != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_cameras.length > 1)
          _cameraButton(
            icon: Icons.flip_camera_android,
            tooltip: 'Ganti Kamera',
            onPressed: _switchCamera,
          ),
        const SizedBox(width: 6),
        _cameraButton(
          icon: running ? Icons.stop : Icons.play_arrow,
          tooltip: running ? 'Hentikan' : 'Mulai',
          onPressed: running ? _stopCamera : _startCamera,
        ),
      ],
    );
  }

  Widget _cameraButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  // ===== KOLOM KANAN: LOG PRESENSI HARI INI =====
  Widget _buildLogCard() {
    final okCount = _dailyLog.where((e) => e.status == 'Berhasil').length;
    return _card(
      title: 'Log Presensi Hari Ini',
      subtitle: '$okCount presensi berhasil',
      child: Expanded(
        child: _dailyLog.isEmpty
            ? const Center(
                child: Text(
                  'Belum ada aktivitas presensi.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              )
            : ListView.separated(
                itemCount: _dailyLog.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => AttendanceLogTile(
                  entry: _dailyLog[index],
                  isLatest: index == 0,
                ),
              ),
      ),
    );
  }
}
