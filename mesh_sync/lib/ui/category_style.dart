import 'package:flutter/material.dart';

import '../messages/mesh_message.dart';

/// One place deciding how each emergency category looks, so the incident list
/// and the detail page cannot drift apart.
Color categoryColor(Category? cat, ThemeData theme) => switch (cat) {
  Category.medical => Colors.red.shade400,
  Category.trapped => Colors.orange.shade700,
  Category.fire => Colors.deepOrange.shade600,
  Category.supplies => Colors.blue.shade500,
  Category.safe => Colors.green.shade600,
  null => theme.disabledColor,
};

IconData categoryIcon(Category? cat) => switch (cat) {
  Category.medical => Icons.medical_services,
  Category.trapped => Icons.emergency,
  Category.fire => Icons.local_fire_department,
  Category.supplies => Icons.inventory_2,
  Category.safe => Icons.check_circle,
  null => Icons.help_outline,
};

IconData updateIcon(UpdateStatus? status) => switch (status) {
  UpdateStatus.stillHere => Icons.hourglass_empty,
  UpdateStatus.worse => Icons.trending_down,
  UpdateStatus.better => Icons.trending_up,
  UpdateStatus.moved => Icons.directions_walk,
  null => Icons.help_outline,
};
