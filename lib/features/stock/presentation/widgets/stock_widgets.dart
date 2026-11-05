import 'package:flutter/material.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/stock.dart';

/// Shared padding for the stock screens' pinned actions: the 56px button
/// ends 12px above the 16px gesture bar.
const stockActionsPadding = EdgeInsets.fromLTRB(16, 8, 16, 12);

/// White bar under Stock 07, 08, 13, 14, running to the screen's edge.
const stockWhiteBar = BoxDecoration(color: RiderColors.white, boxShadow: riderShadow);
const stockWhiteBarPadding = EdgeInsets.fromLTRB(16, 12, 16, 24);

/// "Portions loaded · 3 of 6" and its bar (Stock 01–03, 15, 16).
class StockProgress extends StatelessWidget {
  const StockProgress({super.key, required this.label, required this.done, required this.total});

  final String label;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: RiderText.labelLarge),
          Text('$done of $total', style: RiderText.labelLarge.copyWith(color: RiderColors.brand)),
        ],
      ),
      const SizedBox(height: 16),
      RiderProgressBar(total == 0 ? 0 : done / total, track: RiderColors.progressTrack),
    ],
  );
}

/// 48px rounded photo of an item.
class StockItemImage extends StatelessWidget {
  const StockItemImage(this.image, {super.key});

  final String? image;

  @override
  Widget build(BuildContext context) {
    final path = image;
    const size = 48.0;
    // Decoded for the size shown; the source photos are large.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final placeholder = Container(width: size, height: size, color: RiderColors.photoPlaceholder);
    return ClipRRect(
      borderRadius: BorderRadius.circular(RiderRadius.m),
      child: path == null
          ? placeholder
          : path.startsWith('assets/')
          ? Image.asset(path, width: size, height: size, fit: BoxFit.cover, cacheWidth: pixels)
          : Image.network(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: pixels,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// A line of the stock list: photo, name, "Loaded" / "Scan to load", and on
/// the right the count ([showCount]) and a tick when complete.
class StockItemRow extends StatelessWidget {
  const StockItemRow({super.key, required this.item, required this.count, required this.showCount});

  final StockItem item;
  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final loaded = count >= item.quantity;
    return Row(
      children: [
        StockItemImage(item.image),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: RiderText.labelLarge, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(loaded ? 'Loaded' : 'Scan to load', style: RiderText.caption),
            ],
          ),
        ),
        if (showCount) Text('$count / ${item.quantity}', style: RiderText.labelLarge),
        if (showCount && loaded) const SizedBox(width: 8),
        if (loaded) const RiderTickBadge(),
      ],
    );
  }
}
