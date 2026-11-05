import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ride.dart';
import '../../services/app_session.dart';
import 'driver_home_screen.dart';

/// One-time driver sign-up required before Driver mode unlocks.
/// Document photo upload and verification need a backend and come later.
class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  static final _vehicleNumberPattern = RegExp(r'^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{1,4}$');
  static final _licencePattern = RegExp(r'^[A-Z]{2}[\s-]?\d{2}[\s-]?\d{4}[\s-]?\d{7}$');

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _number = TextEditingController();
  final _licence = TextEditingController();
  VehicleType _vehicle = VehicleType.bike;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _model.dispose();
    _number.dispose();
    _licence.dispose();
    super.dispose();
  }

  String? _required(String? v, String field) => (v == null || v.trim().isEmpty) ? 'Enter $field' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await AppSession.saveDriverProfile(DriverProfile(
      name: _name.text.trim(),
      vehicleType: _vehicle,
      vehicleModel: _model.text.trim(),
      vehicleNumber: _number.text.trim().toUpperCase(),
      licenceNumber: _licence.text.trim().toUpperCase(),
    ));
    await AppSession.setMode(AppMode.driver);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final upper = [UpperCaseTextFormatter()];
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Driver')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Register once to start earning with NinzoRider.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name (as on licence)'),
                validator: (v) => _required(v, 'your name'),
              ),
              const SizedBox(height: 20),
              Text('Vehicle type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<VehicleType>(
                segments: [
                  for (final v in VehicleType.values)
                    ButtonSegment(value: v, label: Text(v.label), icon: Icon(v.icon)),
                ],
                selected: {_vehicle},
                onSelectionChanged: (s) => setState(() => _vehicle = s.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(labelText: 'Vehicle model', hintText: 'e.g. Honda Activa'),
                validator: (v) => _required(v, 'vehicle model'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _number,
                inputFormatters: upper,
                decoration: const InputDecoration(labelText: 'Vehicle number', hintText: 'e.g. DL 3S AB 1234'),
                validator: (v) {
                  final missing = _required(v, 'vehicle number');
                  if (missing != null) return missing;
                  return _vehicleNumberPattern.hasMatch(v!.trim()) ? null : 'Enter a valid vehicle number';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licence,
                inputFormatters: upper,
                decoration:
                    const InputDecoration(labelText: 'Driving licence number', hintText: 'e.g. DL-0420110012345'),
                validator: (v) {
                  final missing = _required(v, 'licence number');
                  if (missing != null) return missing;
                  return _licencePattern.hasMatch(v!.trim()) ? null : 'Enter a valid licence number';
                },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: const Text('Register & Go to Driver mode'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
