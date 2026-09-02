import 'package:flutter/material.dart';

import '../location_service.dart';
import '../messages/mesh_message.dart';

/// A resolved street address above its coordinates.
///
/// The coordinates are the payload and are always shown. The address is a
/// convenience laid over them: the platform geocoder needs the network, so in
/// the situation this app exists for it will usually resolve to nothing, and
/// the widget simply shows one line instead of two.
///
/// Stateful rather than a FutureBuilder so the lookup runs once per coordinate
/// rather than on every rebuild of the list it sits in.
class AddressText extends StatefulWidget {
  const AddressText({
    super.key,
    required this.point,
    required this.location,
    this.style,
  });

  final GeoPoint point;
  final LocationService location;
  final TextStyle? style;

  @override
  State<AddressText> createState() => _AddressTextState();
}

class _AddressTextState extends State<AddressText> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AddressText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point) _resolve();
  }

  Future<void> _resolve() async {
    final address = await widget.location.describe(widget.point);
    if (mounted) setState(() => _address = address);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coordinates =
        '${widget.point.lat.toStringAsFixed(4)}, '
        '${widget.point.lon.toStringAsFixed(4)}';

    if (_address == null) {
      return Text(
        coordinates,
        style: widget.style ?? theme.textTheme.bodyLarge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_address!, style: widget.style ?? theme.textTheme.bodyLarge),
        Text(
          coordinates,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}
