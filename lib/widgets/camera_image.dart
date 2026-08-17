import 'package:flutter/material.dart';

/// Renders a camera device's snapshot, whichever kind of URI it is:
///
///  - `http(s)://...`  -> fetched over the network (e.g. a Pexels demo photo)
///  - `assets/...`     -> bundled with the app (e.g. a photo you supplied)
///  - anything else (e.g. `mock://...`) -> a stylised icon placeholder
///
/// Centralised here so the room-detail preview and the cameras tab render
/// identically instead of drifting apart.
class CameraImage extends StatelessWidget {
  final String uri;
  final bool live;
  final BoxFit fit;

  const CameraImage({super.key, required this.uri, required this.live, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (uri.startsWith('http')) {
      return Image.network(
        uri,
        fit: fit,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
        errorBuilder: (context, error, stack) => _Fallback(live: live),
      );
    }

    if (uri.startsWith('assets/')) {
      return Image.asset(
        uri,
        fit: fit,
        errorBuilder: (context, error, stack) => _Fallback(live: live),
      );
    }

    return _Fallback(live: live);
  }
}

class _Fallback extends StatelessWidget {
  final bool live;

  const _Fallback({required this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: live
              ? const [Color(0xFF1F2A44), Color(0xFF4F46E5)]
              : [Colors.grey.shade700, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          live ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          color: Colors.white.withAlpha((0.85 * 255).round()),
          size: 42,
        ),
      ),
    );
  }
}
