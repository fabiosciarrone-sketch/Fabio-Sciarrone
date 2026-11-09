import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Utility per mostrare le foto profilo in modo sicuro.
///
/// Su Firestore le foto possono essere salvate in tre modi diversi:
/// - un link web (es. "https://images.unsplash.com/...")
/// - un testo base64 puro
/// - un "data URL" (es. "data:image/jpeg;base64,/9j/4AAQ...")
/// Queste funzioni riconoscono il formato e, se il dato è rovinato,
/// restituiscono un segnaposto invece di mandare in crash l'app.
class PhotoUtils {
  PhotoUtils._();

  /// true se la foto è un link web.
  static bool isWebUrl(String? photo) {
    if (photo == null) return false;
    final p = photo.trim().toLowerCase();
    return p.startsWith('http://') || p.startsWith('https://');
  }

  /// Decodifica una foto base64 (anche in formato "data:...;base64,").
  /// Restituisce null se il testo non è un base64 valido.
  static Uint8List? decodeBase64(String? photo) {
    if (photo == null) return null;
    var data = photo.trim();
    if (data.isEmpty || isWebUrl(data) || data.startsWith('blob:')) {
      return null;
    }
    if (data.contains(',')) {
      data = data.split(',').last;
    }
    try {
      final bytes = base64Decode(base64.normalize(data));
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// ImageProvider da usare in CircleAvatar, DecorationImage, ecc.
  /// Restituisce null se la foto è vuota o non valida.
  static ImageProvider? provider(String? photo) {
    if (photo == null || photo.trim().isEmpty) return null;
    if (isWebUrl(photo)) return NetworkImage(photo.trim());
    final bytes = decodeBase64(photo);
    return bytes != null ? MemoryImage(bytes) : null;
  }

  /// Widget immagine pronto all'uso, con segnaposto in caso di foto
  /// mancante, link non raggiungibile o base64 rovinato.
  static Widget image(
    String? photo, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
  }) {
    final fallback = placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[800],
          child: const Icon(Icons.person, color: Colors.white54, size: 40),
        );

    if (photo == null || photo.trim().isEmpty) return fallback;

    if (isWebUrl(photo)) {
      return Image.network(
        photo.trim(),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    final bytes = decodeBase64(photo);
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
