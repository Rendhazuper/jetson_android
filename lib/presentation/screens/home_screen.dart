import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../core/config/app_config.dart';
import '../../core/face/camera_utils.dart';
import '../../core/face/face_preprocessor.dart';
import '../../core/face/face_recognizer.dart';
import '../../data/attendance_service.dart';
import '../../data/daily_log_entry.dart';
import '../../data/person_api_service.dart';

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
  String _confidence = '-';
  String _waktu = '-';

  // Log Harian
  final List<DailyLogEntry> _dailyLog = [];

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: false,
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
      final inputImage = CameraUtils.inputImageFromCameraImage(
        image: image,
        camera: camera,
      );

      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      debugPrint('[FACE DETECT] Faces count: ${faces.length}');

      if (!mounted) return;

      if (faces.isEmpty) {
        return;
      }

      // Ambil wajah terbesar
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final primaryFace = faces.first;
      final box = primaryFace.boundingBox;

      // 1. Potong area wajah langsung dari buffer kamera dengan rotasi yang benar
      final faceCrop = CameraUtils.cropFaceRotated(
        image: image,
        boundingBox: box,
        sensorOrientation: camera.sensorOrientation,
        isFrontCamera: camera.lensDirection == CameraLensDirection.front,
      );

      // 2. Preprocessing (Resize 112x112 + CLAHE + NCHW Float32)
      final nchwFloats = FacePreprocessor.processCroppedFace(faceCrop);

      // 3. Rekognisi via SFace ONNX
      final result = FaceRecognizer.instance.recognize(nchwFloats);

      debugPrint(
        '[RECOG] bestDistance=${result?.distance.toStringAsFixed(3)} '
        'threshold=${result?.threshold} '
        'name=${result?.name} '
        'closest=${result?.closestName}',
      );

      if (result == null || result.name == null) {
        setState(() {
          _eventTitle = 'UNKNOWN';
          _eventColor = const Color(0xFFDC2626);
          _eventMessage =
              'Wajah tidak cocok (dist: ${result?.distance.toStringAsFixed(3) ?? '-'})';
        });
        return;
      }

      final recognizedId = result.name!;
      final confPercent = (result.confidence * 100).toStringAsFixed(1);

      setState(() {
        _eventTitle = 'TERDETEKSI';
        _eventColor = const Color(0xFF16A34A);
        _eventMessage = 'Wajah cocok: $recognizedId ($confPercent%)';
        _confidence = '$confPercent%';
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

    final namaStr = streams?['nama']?.toString() ?? personId;
    final nipStr = streams?['nomorpegawai']?.toString() ?? personId;
    final unitStr = streams?['nama_unit_kerja']?.toString() ?? '-';
    final waktuStr = streams?['waktu']?.toString() ?? timeStr;

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
            idPegawai: personId,
            nama: personId,
            status: 'Gagal',
            message: apiRes.message,
          ),
        );
      }
    });

    if (apiRes.ok) {
      _showAttendanceSuccessDialog(
        nama: namaStr,
        nomor: nipStr,
        unit: unitStr,
        waktu: waktuStr,
      );
    }
  }

  /// Pop-up presensi berhasil, ditampilkan otomatis lalu menutup sendiri.
  void _showAttendanceSuccessDialog({
    required String nama,
    required String nomor,
    required String unit,
    required String waktu,
  }) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        // Tutup otomatis setelah 2,5 detik.
        Future<void>.delayed(const Duration(milliseconds: 2500), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PRESENSI BERHASIL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nama,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nomor,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  unit,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      waktu,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildControlsBar(),
            Expanded(
              child: isLandscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _buildCameraCard()),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: _buildInformationPanel()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: _buildCameraCard()),
                        Expanded(flex: 5, child: _buildInformationPanel()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 1. HEADER (Dark Charcoal sesuai Image 1) =====
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Image.asset(
            AppConfig.logoAsset,
            width: 38,
            height: 38,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.school,
              color: Colors.amber,
              size: 36,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Universitas Jember',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Face Recognition Presence',
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'CDAST 5',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 2. CONTROLS BAR =====
  Widget _buildControlsBar() {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _cameraController == null ? _startCamera : _stopCamera,
            icon: Icon(
              _cameraController == null ? Icons.play_arrow : Icons.stop,
              size: 16,
            ),
            label: Text(_cameraController == null ? 'Mulai' : 'Hentikan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_android, size: 20),
              onPressed: _switchCamera,
              tooltip: 'Ganti Kamera',
            ),
          const Spacer(),
          Text(
            _status,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ===== 3. CAMERA CARD (Object-Fit Cover Tanpa Distorsi) =====
  Widget _buildCameraCard() {
    final controller = _cameraController;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF05080D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: controller != null && controller.value.isInitialized
          ? LayoutBuilder(
              builder: (context, constraints) {
                final previewSize = controller.value.previewSize;
                if (previewSize == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Pada Android portrait, dimensi sensor ditukar (tinggi jadi lebar dan sebaliknya)
                final isPortrait =
                    MediaQuery.of(context).orientation == Orientation.portrait;
                final double previewWidth =
                    isPortrait ? previewSize.height : previewSize.width;
                final double previewHeight =
                    isPortrait ? previewSize.width : previewSize.height;

                final previewAspect = previewWidth / previewHeight;
                final containerAspect =
                    constraints.maxWidth / constraints.maxHeight;

                // Hitung skala cover tanpa distorsi
                double scale;
                if (containerAspect > previewAspect) {
                  scale = containerAspect / previewAspect;
                } else {
                  scale = previewAspect / containerAspect;
                }

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
            )
          : const Center(
              child: Text(
                'Memuat kamera...',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ),
    );
  }

  // ===== 4. INFORMATION PANEL & LOG HARIAN =====
  Widget _buildInformationPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INFORMASI HASIL DETEKSI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _eventTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _eventColor,
            ),
          ),
          Text(
            _eventMessage,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 10),

          // Fields Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _buildFieldRow('Nama', _nama),
                _buildFieldRow('NIM / NIP', _nomorPegawai),
                _buildFieldRow('Unit / Prodi', _unitKerja),
                _buildFieldRow('Confidence', _confidence),
                _buildFieldRow('Waktu', _waktu),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Log Presensi Section
          const Text(
            'LOG PRESENSI HARI INI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _dailyLog.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada aktivitas presensi.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _dailyLog.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = _dailyLog[index];
                        final isOk = entry.status == 'Berhasil';

                        return Row(
                          children: [
                            Text(
                              entry.time,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Badge ID (Biru)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.idPegawai,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Badge Nama (Oranye)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.nama,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            Text(
                              '- ${entry.status}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isOk
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const Text(' : ', style: TextStyle(color: Color(0xFF6B7280))),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF1E1E1E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
