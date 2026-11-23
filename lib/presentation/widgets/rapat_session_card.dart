import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_palette.dart';
import '../../data/rapat_api_service.dart';

/// Panjang kode rapat (contoh di API: `R7K2QM`).
const int kodeRapatLength = 6;

const _brandGreen = Color(0xFF2FA23A);
const _brandRed = Color(0xFFDC2626);

/// Kartu "Sesi Rapat": menampilkan sesi yang sedang dibuka dan tombol
/// Mulai Sesi (tanpa sesi) atau Akhiri Sesi (dengan sesi).
class RapatSessionCard extends StatelessWidget {
  const RapatSessionCard({
    super.key,
    required this.session,
    required this.busy,
    required this.onStart,
    required this.onEnd,
  });

  final RapatSession? session;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final current = session;
    final active = current != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
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
                  color: _brandGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sesi Rapat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (current != null) ...[
            Text(
              current.judul,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${current.tempat} • ${current.mulai}–${current.selesai}',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ] else
            Text(
              'Belum ada sesi rapat aktif.',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: active ? _brandRed : _brandGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: busy ? null : (active ? onEnd : onStart),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      active
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
              label: Text(active ? 'Akhiri Sesi' : 'Mulai Sesi'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog input kode rapat dengan kotak per karakter (pinput). Mengembalikan
/// kode huruf besar, atau `null` bila dibatalkan.
Future<String?> showKodeRapatDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String subtitle = 'Kode ada di detail rapat > tab Presensi di SIAKAD.',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _KodeRapatDialog(
      title: title,
      actionLabel: actionLabel,
      subtitle: subtitle,
    ),
  );
}

class _KodeRapatDialog extends StatefulWidget {
  const _KodeRapatDialog({
    required this.title,
    required this.actionLabel,
    required this.subtitle,
  });

  final String title;
  final String actionLabel;
  final String subtitle;

  @override
  State<_KodeRapatDialog> createState() => _KodeRapatDialogState();
}

class _KodeRapatDialogState extends State<_KodeRapatDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _complete = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final complete = value.trim().length == kodeRapatLength;
    if (complete != _complete) setState(() => _complete = complete);
  }

  void _submit() {
    final kode = _controller.text.trim().toUpperCase();
    if (kode.length != kodeRapatLength) return;
    Navigator.pop(context, kode);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final defaultTheme = PinTheme(
      width: 46,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.track),
      ),
    );
    final focusedTheme = PinTheme(
      width: 46,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _brandGreen, width: 2),
      ),
    );

    return Dialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _brandGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        AppConfig.logoAsset,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.school, color: _brandGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: Pinput(
                        length: kodeRapatLength,
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        defaultPinTheme: defaultTheme,
                        focusedPinTheme: focusedTheme,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[A-Za-z0-9]'),
                          ),
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => newValue.copyWith(
                              text: newValue.text.toUpperCase(),
                            ),
                          ),
                        ],
                        onChanged: _onChanged,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.track),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _complete ? _submit : null,
                        child: Text(widget.actionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
