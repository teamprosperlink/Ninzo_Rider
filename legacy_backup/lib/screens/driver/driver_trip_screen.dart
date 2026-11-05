import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../../models/ride.dart';
import '../../services/driver_controller.dart';
import '../../widgets/map_view.dart';

class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  final _otp = TextEditingController();
  String? _otpError;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  void _startTrip() {
    if (widget.controller.startTrip(_otp.text)) {
      setState(() => _otpError = null);
    } else {
      setState(() => _otpError = 'Wrong OTP, ask the rider again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ride = widget.controller.activeRide;
        if (ride == null) return const Scaffold();
        final title = switch (ride.status) {
          RideStatus.driverArrived => 'At pickup',
          RideStatus.inProgress => 'Trip in progress',
          RideStatus.completed => 'Trip completed',
          _ => 'Go to pickup',
        };
        return PopScope(
          canPop: false,
          child: Scaffold(
            appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
            body: Column(
              children: [
                Expanded(
                  child: MapView(
                    center: ride.status == RideStatus.inProgress ? ride.drop.point : ride.pickup.point,
                    zoom: 13,
                    markers: [
                      mapPin(ride.pickup.point, Icons.my_location, AppTheme.pickupColor),
                      mapPin(ride.drop.point, Icons.location_on, AppTheme.dropColor),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text(ride.riderName[0])),
                          title: Text(ride.riderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            ride.status == RideStatus.inProgress
                                ? 'Drop: ${ride.drop.name}'
                                : 'Pickup: ${ride.pickup.name}',
                          ),
                          trailing: Text(
                            rupees(ride.fare),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._actions(context, ride),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context, Ride ride) {
    final c = widget.controller;
    switch (ride.status) {
      case RideStatus.driverArrived:
        return [
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Enter rider OTP',
              helperText: 'Demo OTP: ${ride.otp}',
              errorText: _otpError,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _startTrip, child: const Text('Start Trip')),
        ];
      case RideStatus.inProgress:
        return [FilledButton(onPressed: c.completeTrip, child: const Text('Complete Trip'))];
      case RideStatus.completed:
        return [
          Text(
            'Collect ${rupees(ride.fare)} in cash',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              c.finishTrip();
            },
            child: const Text('Done'),
          ),
        ];
      case RideStatus.searching:
      case RideStatus.driverAssigned:
        return [FilledButton(onPressed: c.markArrived, child: const Text('Arrived at Pickup'))];
    }
  }
}
