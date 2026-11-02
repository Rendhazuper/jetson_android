import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class PersonApiResponse {
  const PersonApiResponse({
    required this.ok,
    this.status,
    required this.message,
    this.data,
  });

  final bool ok;
  final int? status;
  final String message;
  final Map<String, dynamic>? data;
}

/// Layanan pengiriman ID personal ke API layanan perkuliahan.
/// Padanan dari `services/person_api_service.py`.
class PersonApiService {
  Future<PersonApiResponse> sendPersonId(String idPersonal) async {
    final url = AppConfig.personInfoApiUrl;
    if (url.isEmpty) {
      return PersonApiResponse(
        ok: true,
        status: 200,
        message: 'Mode demo offline (URL API belum diset).',
        data: {
          'streams': {
            'nama': idPersonal,
            'nomorpegawai': idPersonal,
            'nama_unit_kerja': 'Demo Presensi',
            'waktu': DateTime.now().toString().substring(11, 19),
          }
        },
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'idpersonal': idPersonal}),
          )
          .timeout(
            const Duration(seconds: AppConfig.personInfoApiTimeoutSeconds),
          );

      Map<String, dynamic>? parsed;
      if (response.body.isNotEmpty) {
        try {
          parsed = jsonDecode(response.body) as Map<String, dynamic>?;
        } catch (_) {}
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PersonApiResponse(
          ok: true,
          status: response.statusCode,
          message: 'Data berhasil dikirim ke API.',
          data: parsed,
        );
      } else {
        return PersonApiResponse(
          ok: false,
          status: response.statusCode,
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          data: parsed,
        );
      }
    } on SocketException catch (e) {
      return PersonApiResponse(
        ok: false,
        message: 'Jaringan tidak dapat dihubungi: ${e.message}',
      );
    } on HttpException catch (e) {
      return PersonApiResponse(
        ok: false,
        message: 'HTTP Error: ${e.message}',
      );
    } catch (e) {
      return PersonApiResponse(
        ok: false,
        message: 'Gagal menghubungi API: $e',
      );
    }
  }
}
