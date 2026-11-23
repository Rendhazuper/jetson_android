import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/content/consent_text.dart';
import '../../core/enroll/enroll_rules.dart';
import '../../core/theme/app_palette.dart';
import '../widgets/enroll_oval_guide.dart';

const _brandGreen = Color(0xFF2FA23A);
const _brandGreenDark = Color(0xFF1F7F2B);
const _danger = Color(0xFFDC2626);
const _warn = Color(0xFFD97706);

const _cameraTips = [
  'Wajah di tengah oval',
  'Cahaya dari depan, bukan dari belakang',
  'Lepas masker, topi, kacamata hitam',
  'Gerakkan kepala pelan-pelan mengikuti panah (±18 detik)',
];

/// Dialog input NIP/NRP/NIK sebelum persetujuan. Mengembalikan nilai yang
/// sudah dirapikan, atau `null` bila dibatalkan.
Future<String?> showEnrollNipDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NipDialog(),
  );
}

class _NipDialog extends StatefulWidget {
  const _NipDialog();

  @override
  State<_NipDialog> createState() => _NipDialogState();
}

class _NipDialogState extends State<_NipDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Format sama dengan halaman /rekam. Spasi di ujung diabaikan.
  bool get _valid => isValidPersonRef(_controller.text);

  /// Pesan galat hanya muncul setelah ada isian yang tidak sesuai format.
  bool get _showError => _controller.text.trim().isNotEmpty && !_valid;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return AlertDialog(
      backgroundColor: p.card,
      title: Text(
        'Enroll Wajah Baru',
        style: TextStyle(color: p.ink, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masukkan nomor identitas orang yang akan direkam.',
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Nomor identitas (NIP / NIM / NIK)',
              hintText: 'mis. 1234567890',
              helperText:
                  'Huruf, angka, titik, garis bawah, atau tanda hubung; '
                  '3–32 karakter.',
              errorText: _showError
                  ? 'Format nomor identitas belum sesuai.'
                  : null,
              filled: true,
              fillColor: p.pageBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _brandGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: _valid ? _submit : null,
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}

enum _EnrollStep { consent, camera, review }

enum _StepState { done, active, todo }

/// Layar enroll mengikuti alur halaman /rekam: persetujuan, cek kamera dengan
/// panduan oval, rekam (hitung mundur lalu perintah arah), dan tinjau.
/// Pengiriman ke server belum dihubungkan.
class EnrollScreen extends StatefulWidget {
  const EnrollScreen({super.key, required this.nip});

  /// NIP/NRP/NIK dari dialog. Hanya ditampilkan di layar ini.
  final String nip;

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  static const _cameraBg = Color(0xFF05080D);
  static const _ratioLandscape = 4 / 3;
  static const _ratioPortrait = 3 / 4;

  _EnrollStep _step = _EnrollStep.consent;

  // Persetujuan: tombol setuju aktif setelah teks digulir sampai akhir.
  final _consentScroll = ScrollController();
  bool _consentRead = false;
  bool _consentChecked = false;

  // Kamera dan rekaman. `_runId` membatalkan rekaman yang sedang berjalan.
  CameraController? _camera;
  String? _cameraError;
  String? _recordError;
  bool _recording = false;
  int? _countdown;
  String? _promptDirection;
  double _progress = 0;
  int _runId = 0;

  // Tinjau: video hasil rekaman, dihapus bila diulang atau layar ditutup.
  String? _recordedPath;
  Duration _recordedDuration = Duration.zero;
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _consentScroll.addListener(_checkConsentRead);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConsentRead());
  }

  @override
  void dispose() {
    _consentScroll.dispose();
    unawaited(_releaseCamera());
    unawaited(_discardReview());
    super.dispose();
  }

  void _checkConsentRead() {
    if (!mounted || _consentRead || !_consentScroll.hasClients) return;
    final position = _consentScroll.position;
    final atEnd = position.pixels >= position.maxScrollExtent - 8;
    if (position.maxScrollExtent <= 0 || atEnd) {
      setState(() => _consentRead = true);
    }
  }

  void _setujui() {
    setState(() => _step = _EnrollStep.camera);
    unawaited(_initCamera());
  }

  Future<void> _kembaliKePersetujuan() async {
    await _releaseCamera();
    if (!mounted) return;
    setState(() {
      _step = _EnrollStep.consent;
      _cameraError = null;
      _recordError = null;
      _recording = false;
      _countdown = null;
      _promptDirection = null;
      _progress = 0;
    });
  }

  /// Membuka kamera depan setelah persetujuan. Izin kamera sudah dijamin
  /// gerbang di atas aplikasi, jadi di sini hanya kegagalan perangkat.
  Future<void> _initCamera() async {
    if (_camera != null) return;
    CameraController? controller;
    String? error;
    try {
      final cameras = await availableCameras();
      final front = cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();
      if (front.isEmpty) {
        error = 'Kamera depan tidak ditemukan.';
      } else {
        controller = CameraController(
          front.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller.initialize();
      }
    } catch (e) {
      debugPrint('[ENROLL CAMERA] $e');
      error = 'Gagal membuka kamera depan.';
    }

    if (error != null) {
      await controller?.dispose();
      controller = null;
    }
    if (!mounted) {
      await controller?.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _cameraError = error;
    });
  }

  bool _isCurrentRun(int runId) => mounted && runId == _runId;

  /// Hitung mundur, lalu rekam sambil memberi perintah arah berurutan.
  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null || _recording) return;
    final runId = ++_runId;
    final challenge = enrollChallenge(Random());

    setState(() {
      _recording = true;
      _recordError = null;
      _countdown = kEnrollCountdownSeconds;
      _promptDirection = null;
      _progress = 0;
    });

    for (var n = kEnrollCountdownSeconds; n > 0; n--) {
      if (!_isCurrentRun(runId)) return;
      setState(() => _countdown = n);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!_isCurrentRun(runId)) return;

    try {
      await camera.startVideoRecording();
    } catch (e) {
      debugPrint('[ENROLL RECORD] $e');
      if (!_isCurrentRun(runId)) return;
      setState(() {
        _recording = false;
        _countdown = null;
        _recordError = 'Gagal memulai rekaman. Coba lagi.';
      });
      return;
    }
    if (!_isCurrentRun(runId)) {
      await _discardRecording(camera);
      return;
    }

    final total = kEnrollStepDuration * challenge.length;
    final clock = Stopwatch()..start();
    setState(() => _countdown = null);
    while (_isCurrentRun(runId) && clock.elapsed < total) {
      final elapsed = clock.elapsed;
      final index =
          elapsed.inMilliseconds ~/ kEnrollStepDuration.inMilliseconds;
      setState(() {
        _promptDirection = challenge[index];
        _progress = elapsed.inMilliseconds / total.inMilliseconds;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!_isCurrentRun(runId)) return;

    String? path;
    try {
      final file = await camera.stopVideoRecording();
      path = file.path;
    } catch (e) {
      debugPrint('[ENROLL RECORD] $e');
    }
    if (!_isCurrentRun(runId)) {
      if (path != null) await _deleteFile(path);
      return;
    }
    if (path == null) {
      setState(() {
        _recording = false;
        _promptDirection = null;
        _progress = 0;
        _recordError = 'Gagal menyimpan rekaman. Coba lagi.';
      });
      return;
    }

    final video = VideoPlayerController.file(File(path));
    try {
      await video.initialize();
      await video.setLooping(true);
    } catch (e) {
      debugPrint('[ENROLL REVIEW] $e');
      await video.dispose();
      await _deleteFile(path);
      if (!_isCurrentRun(runId)) return;
      setState(() {
        _recording = false;
        _promptDirection = null;
        _progress = 0;
        _recordError = 'Rekaman tidak bisa diputar. Coba lagi.';
      });
      return;
    }
    if (!_isCurrentRun(runId)) {
      await video.dispose();
      await _deleteFile(path);
      return;
    }

    setState(() {
      _recording = false;
      _promptDirection = null;
      _progress = 1;
      _recordedPath = path;
      _recordedDuration = clock.elapsed;
      _video = video;
      _step = _EnrollStep.review;
    });
    unawaited(video.play());
  }

  Future<void> _batalkanRekaman() async {
    _runId++;
    final camera = _camera;
    setState(() {
      _recording = false;
      _countdown = null;
      _promptDirection = null;
      _progress = 0;
    });
    if (camera != null) await _discardRecording(camera);
  }

  /// Menghentikan rekaman yang sedang berjalan dan membuang hasilnya.
  Future<void> _discardRecording(CameraController camera) async {
    try {
      if (camera.value.isRecordingVideo) {
        final file = await camera.stopVideoRecording();
        await _deleteFile(file.path);
      }
    } catch (e) {
      debugPrint('[ENROLL RECORD] $e');
    }
  }

  Future<void> _releaseCamera() async {
    _runId++;
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    await _discardRecording(camera);
    await camera.dispose();
  }

  Future<void> _discardReview() async {
    final video = _video;
    final path = _recordedPath;
    _video = null;
    _recordedPath = null;
    await video?.dispose();
    if (path != null) await _deleteFile(path);
  }

  Future<void> _ulangi() async {
    await _discardReview();
    if (!mounted) return;
    setState(() => _step = _EnrollStep.camera);
  }

  /// TODO: unggah video ke server pendaftaran setelah kontrak API enroll
  /// tersedia. Sampai saat itu, tombol ini hanya memberi tahu.
  void _kirim() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengiriman belum dihubungkan.')),
    );
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (e) {
      debugPrint('[ENROLL FILE] $e');
    }
  }

  void _togglePlay(VideoPlayerController video) {
    if (video.value.isPlaying) {
      unawaited(video.pause());
    } else {
      unawaited(video.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBackground,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNipChip(p),
                  const SizedBox(height: 12),
                  _buildStepBar(p),
                  const SizedBox(height: 16),
                  Expanded(child: _buildStepBody(p)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_brandGreenDark, _brandGreen]),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kembali ke menu',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Enroll Wajah Baru',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNipChip(AppPalette p) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'NIP/NRP/NIK: ${widget.nip}',
          style: TextStyle(
            color: p.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Penanda tahap seperti di halaman /rekam. Identitas sudah diisi lewat
  /// dialog, jadi selalu selesai. Selesai belum ada karena pengiriman
  /// belum dihubungkan.
  Widget _buildStepBar(AppPalette p) {
    final current = switch (_step) {
      _EnrollStep.consent => 1,
      _EnrollStep.camera => 2,
      _EnrollStep.review => 3,
    };
    const labels = ['Identitas', 'Persetujuan', 'Rekam', 'Tinjau', 'Selesai'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          _stepChip(
            p,
            i + 1,
            labels[i],
            i < current
                ? _StepState.done
                : i == current
                ? _StepState.active
                : _StepState.todo,
          ),
      ],
    );
  }

  Widget _stepChip(AppPalette p, int number, String label, _StepState state) {
    final active = state == _StepState.active;
    final done = state == _StepState.done;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? p.greenSoft : p.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: done || active ? _brandGreen : p.track,
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : p.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: done || active ? _brandGreen : p.muted,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(AppPalette p) {
    return switch (_step) {
      _EnrollStep.consent => _buildConsent(p),
      _EnrollStep.camera => _buildCamera(p),
      _EnrollStep.review => _buildReview(p),
    };
  }

  Widget _buildConsent(AppPalette p) {
    // Seperti max-h-[45vh] di web: teks persetujuan dibatasi tinggi layar.
    final maxTextHeight = MediaQuery.sizeOf(context).height * 0.45;
    return _Panel(
      p: p,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Persetujuan',
              style: TextStyle(
                color: p.ink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Baca dengan saksama, atau bacakan kepada orang yang direkam, '
              'sampai akhir sebelum melanjutkan.',
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                kConsentDraftNotice,
                style: TextStyle(
                  color: _warn,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxTextHeight),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.pageBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Scrollbar(
                  controller: _consentScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const ValueKey('consent-scroll'),
                    controller: _consentScroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kConsentHeading,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          kConsentIntro,
                          style: TextStyle(color: p.ink, fontSize: 13),
                        ),
                        for (final section in kConsentSections) ...[
                          const SizedBox(height: 12),
                          Text(
                            section.title,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section.body,
                            style: TextStyle(color: p.ink, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_consentRead)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Gulir teks persetujuan sampai akhir untuk dapat menyetujui.',
                  style: TextStyle(
                    color: _warn,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            CheckboxListTile(
              value: _consentChecked,
              onChanged: _consentRead
                  ? (value) => setState(() => _consentChecked = value ?? false)
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: _brandGreen,
              title: Text(
                kConsentCheckLabel,
                style: TextStyle(color: p.ink, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Kembali'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: _greenButtonStyle(),
                    onPressed: _consentChecked ? _setujui : null,
                    child: const Text('Setuju & lanjut'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera(AppPalette p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final ratio = portrait ? _ratioPortrait : _ratioLandscape;
        final box = AspectRatio(
          aspectRatio: ratio,
          child: _buildCameraBox(widthFactor: portrait ? 0.6 : 0.4),
        );
        return _split(
          wide: constraints.maxWidth >= 900,
          box: box,
          sidebar: _buildCameraSidebar(p),
          actions: _buildCameraActions(),
        );
      },
    );
  }

  Widget _buildCameraBox({required double widthFactor}) {
    final recording = _recording && _countdown == null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: _cameraBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(),
            EnrollOvalGuide(widthFactor: widthFactor),
            Positioned(left: 16, top: 16, child: _cameraChip('Kamera Depan')),
            if (recording) Positioned(right: 16, top: 16, child: _recChip()),
            if (_countdown != null)
              Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            if (_promptDirection != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: recording ? 6 : 0,
                child: _promptView(_promptDirection!),
              ),
            if (recording)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  color: _danger,
                  backgroundColor: Colors.white24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSidebar(AppPalette p) {
    final busy = _recording;
    return _Panel(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            busy ? 'Sedang merekam' : 'Cek kamera',
            style: TextStyle(
              color: p.ink,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (!busy) ...[
            Text(
              'Pastikan sebelum mulai:',
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final tip in _cameraTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 16, color: _brandGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(color: p.ink, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_recordError != null || _cameraError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _recordError ?? _cameraError!,
                style: const TextStyle(color: _danger, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReview(AppPalette p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final video = _video;
        final box = video == null || !video.value.isInitialized
            ? const AspectRatio(
                aspectRatio: _ratioLandscape,
                child: Center(child: CircularProgressIndicator()),
              )
            : AspectRatio(
                aspectRatio: video.value.aspectRatio > 0
                    ? video.value.aspectRatio
                    : _ratioLandscape,
                child: GestureDetector(
                  onTap: () => _togglePlay(video),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ColoredBox(
                      color: _cameraBg,
                      child: VideoPlayer(video),
                    ),
                  ),
                ),
              );
        return _split(
          wide: constraints.maxWidth >= 900,
          box: box,
          sidebar: _buildReviewSidebar(p),
          actions: _buildReviewActions(),
        );
      },
    );
  }

  Widget _buildReviewSidebar(AppPalette p) {
    final seconds = (_recordedDuration.inMilliseconds / 1000).toStringAsFixed(
      1,
    );
    return _Panel(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tinjau rekaman',
            style: TextStyle(
              color: p.ink,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Putar ulang dan pastikan wajah terlihat jelas di setiap arah.',
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'Durasi $seconds detik',
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Area utama (kamera atau video) dengan panel samping di layar lebar.
  /// Tombol aksi selalu di bawah. Di layar sempit area utama bisa digulir,
  /// sehingga tinggi kamera mengikuti lebar layar dan tidak terpotong.
  Widget _split({
    required bool wide,
    required Widget box,
    required Widget sidebar,
    required Widget actions,
  }) {
    final content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: box)),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: sidebar),
            ],
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [box, const SizedBox(height: 12), sidebar],
            ),
          );
    return Column(
      children: [
        Expanded(child: content),
        const SizedBox(height: 16),
        _actionBar(actions),
      ],
    );
  }

  /// Tombol aksi di bawah area utama, lebarnya dibatasi seperti tombol lain.
  Widget _actionBar(Widget actions) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(width: double.infinity, child: actions),
      ),
    );
  }

  Widget _buildCameraActions() {
    if (_recording) {
      return OutlinedButton(
        style: _outlinedButtonStyle(color: _danger),
        onPressed: () => unawaited(_batalkanRekaman()),
        child: const Text('Batal'),
      );
    }
    return Row(
      children: [
        OutlinedButton(
          style: _outlinedButtonStyle(),
          onPressed: () => unawaited(_kembaliKePersetujuan()),
          child: const Text('Kembali'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: _greenButtonStyle(),
            onPressed: _camera != null
                ? () => unawaited(_startRecording())
                : null,
            child: const Text('Mulai merekam'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewActions() {
    return Row(
      children: [
        OutlinedButton(
          style: _outlinedButtonStyle(),
          onPressed: () => unawaited(_ulangi()),
          child: const Text('Ulangi'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: _greenButtonStyle(),
            onPressed: _kirim,
            child: const Text('Kirim'),
          ),
        ),
      ],
    );
  }

  ButtonStyle _outlinedButtonStyle({Color? color}) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  ButtonStyle _greenButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _brandGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  Widget _buildPreview() {
    final camera = _camera;
    if (camera == null) {
      return Center(
        child: Text(
          _cameraError ?? 'Memuat kamera...',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
      );
    }

    final size = camera.value.previewSize;
    if (size == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Sensor pada Android portrait ditukar, sama seperti di layar pengenalan.
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final width = isPortrait ? size.height : size.width;
    final height = isPortrait ? size.width : size.height;

    // Pratinjau dicerminkan agar terasa seperti cermin, rekaman tidak.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: height,
        child: Transform.flip(flipX: true, child: CameraPreview(camera)),
      ),
    );
  }

  Widget _promptView(String direction) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xD9000000), Color(0x80000000), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_directionIcon(direction), size: 64, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            kEnrollPrompts[direction] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _directionIcon(String direction) => switch (direction) {
    'kiri' => Icons.arrow_back,
    'kanan' => Icons.arrow_forward,
    'atas' => Icons.arrow_upward,
    'bawah' => Icons.arrow_downward,
    _ => Icons.radio_button_checked,
  };

  Widget _recChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _danger,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: Colors.white),
          SizedBox(width: 6),
          Text(
            'REKAM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
}

/// Kartu putih atau gelap seperti kartu di halaman lain.
class _Panel extends StatelessWidget {
  const _Panel({required this.p, required this.child});

  final AppPalette p;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material menjadi permukaan untuk ListTile di dalam kartu.
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
