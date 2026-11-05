import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';

/// Register 14 (search your area), 15 (results) and 16 (no results).
class AreaPage extends ConsumerStatefulWidget {
  const AreaPage({super.key});

  @override
  ConsumerState<AreaPage> createState() => _AreaPageState();
}

class _AreaPageState extends ConsumerState<AreaPage> {
  late final _query = TextEditingController(
    text: ref.read(registerViewModelProvider).query,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerViewModelProvider);
    final vm = ref.read(registerViewModelProvider.notifier);
    final typed = state.query.trim().isNotEmpty;
    final noResults = typed && !state.searching && state.results.isEmpty;

    final useLocation = RiderPlaceRow(
      key: const Key('useLocation'),
      title: 'Use my current location',
      subtitle: 'Turn on location to find your area',
      icon: Icons.pin_drop_outlined,
      highlight: true,
      onTap: vm.useCurrentLocation,
    );
    return RegisterScaffold(
      title: 'Your area',
      onBack: vm.closeArea,
      children: [
        RiderIconField(
          icon: Icons.pin_drop_outlined,
          controller: _query,
          fieldKey: const Key('areaSearch'),
          hint: 'Search area, town or junction',
          tone: RiderFieldTone.active,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.search,
          onChanged: vm.search,
        ),
        if (noResults)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RegisterHeading(
                  'No area found',
                  'Check the spelling, or search a nearby town or junction.',
                ),
                const SizedBox(height: 8),
                useLocation,
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!typed) useLocation,
              for (final area in state.results)
                RiderPlaceRow(
                  title: area.name,
                  subtitle: area.city,
                  icon: Icons.pin_drop_outlined,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    vm.selectArea(area);
                  },
                ),
            ],
          ),
      ],
    );
  }
}
