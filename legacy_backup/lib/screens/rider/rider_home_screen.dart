import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/mock_data.dart';
import '../../models/ride.dart';
import '../../services/app_session.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/map_view.dart';
import '../../widgets/place_search_sheet.dart';
import 'ride_history_screen.dart';
import 'ride_tracking_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final _controller = AppSession.rider;
  final Place _pickup = MockData.currentLocation;
  Place? _drop;
  VehicleType _vehicle = VehicleType.bike;

  Future<void> _chooseDrop() async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const PlaceSearchSheet(),
    );
    if (place != null) setState(() => _drop = place);
  }

  Future<void> _book() async {
    _controller.bookRide(pickup: _pickup, drop: _drop!, vehicle: _vehicle);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RideTrackingScreen(controller: _controller)),
    );
    if (mounted) setState(() => _drop = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        items: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('My Rides'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RideHistoryScreen(rides: _controller.history)),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapView(
            center: _pickup.point,
            markers: [
              mapPin(_pickup.point, Icons.my_location, AppTheme.pickupColor),
              if (_drop != null) mapPin(_drop!.point, Icons.location_on, AppTheme.dropColor),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Builder(
                builder: (ctx) => FloatingActionButton.small(
                  heroTag: null,
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  child: const Icon(Icons.menu),
                ),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildPanel(context)),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final drop = _drop;
    final km = drop == null ? 0.0 : Ride.kmBetween(_pickup.point, drop.point);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Where to?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location, color: AppTheme.pickupColor),
              title: Text(_pickup.name),
              subtitle: Text(_pickup.address),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on, color: AppTheme.dropColor),
              title: Text(drop?.name ?? 'Enter drop location'),
              subtitle: drop == null ? null : Text(drop.address),
              trailing: const Icon(Icons.search),
              onTap: _chooseDrop,
            ),
            if (drop != null) ...[
              const Divider(),
              Text('${km.toStringAsFixed(1)} km • Choose a ride', style: theme.textTheme.labelLarge),
              for (final v in VehicleType.values)
                _VehicleOption(
                  vehicle: v,
                  fare: v.fareFor(km),
                  selected: v == _vehicle,
                  onTap: () => setState(() => _vehicle = v),
                ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _book, child: Text('Book ${_vehicle.label}')),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({required this.vehicle, required this.fare, required this.selected, required this.onTap});

  final VehicleType vehicle;
  final double fare;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(vehicle.icon, size: 30),
        title: Text(vehicle.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(rupees(fare), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        onTap: onTap,
      ),
    );
  }
}
