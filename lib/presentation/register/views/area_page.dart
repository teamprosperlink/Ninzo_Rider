import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

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
      key: const Key(AppKeys.uselocation),
      title: AppStrings.useMyCurrentLocation,
      subtitle: AppStrings.turnOnLocationToFindYour,
      icon: Icons.pin_drop_outlined,
      highlight: true,
      onTap: vm.useCurrentLocation,
    );
    return RegisterScaffold(
      title: AppStrings.yourArea,
      onBack: vm.closeArea,
      children: [
        RiderIconField(
          icon: Icons.pin_drop_outlined,
          controller: _query,
          fieldKey: const Key(AppKeys.areasearch),
          hint: AppStrings.searchAreaTownOrJunction,
          tone: RiderFieldTone.active,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.search,
          onChanged: vm.search,
        ),
        if (noResults)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.s32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RegisterHeading(
                  AppStrings.noAreaFound,
                  AppStrings.checkTheSpellingOrSearchA,
                ),
                const SizedBox(height: AppSizes.s8),
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
