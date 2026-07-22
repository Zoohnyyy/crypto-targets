import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'zec_logo.dart';

/// A coin's logo, cached from the network, with a lettered-circle fallback.
///
/// Falls back to a colored circle with the ticker's first letters whenever
/// there is no image URL or the image fails to load — so coins without a
/// mapped logo (or offline) still render cleanly.
///
/// A few coins have a bundled, theme-aware override (see [_themedOverride])
/// because the network logo doesn't adapt to dark/light mode — e.g. ZEC's Z
/// must be white on dark, black on light.
class CoinLogo extends StatelessWidget {
  const CoinLogo({
    super.key,
    required this.ticker,
    this.imageUrl,
    this.size = 40,
  });

  final String ticker;
  final String? imageUrl;
  final double size;

  /// Returns a bundled theme-aware logo for tickers that need one, else null.
  Widget? _themedOverride(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    switch (ticker.toUpperCase()) {
      case 'ZEC':
        return ZecLogo(size: size, brightness: brightness);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final override = _themedOverride(context);
    if (override != null) return override;

    final fallback = _LetterAvatar(ticker: ticker, size: size);
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
        fadeInDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}

class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({required this.ticker, required this.size});

  final String ticker;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        ticker.characters.take(3).toString(),
        style: TextStyle(
          fontSize: size * 0.28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
