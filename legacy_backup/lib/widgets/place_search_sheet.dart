import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/ride.dart';

/// Bottom sheet for picking a drop location from the (mock) place list.
class PlaceSearchSheet extends StatefulWidget {
  const PlaceSearchSheet({super.key});

  @override
  State<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<PlaceSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final results = MockData.places
        .where((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search drop location',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No places found'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final Place place = results[i];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(place.name),
                          subtitle: Text(place.address),
                          onTap: () => Navigator.pop(context, place),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
