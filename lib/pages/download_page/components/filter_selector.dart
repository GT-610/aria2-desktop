import 'package:flutter/material.dart';
import '../enums/category_type.dart';
import '../enums/filter_option.dart';

// Filter selector component for task filtering functionality
class FilterSelector extends StatelessWidget {
  final FilterOption selectedFilter;
  final CategoryType currentCategoryType;
  final Map<String, String> instanceNames;
  final Function(FilterOption) onFilterChanged;
  final Function(CategoryType) onCategoryChanged;

  const FilterSelector({
    Key? key,
    required this.selectedFilter,
    required this.currentCategoryType,
    required this.instanceNames,
    required this.onFilterChanged,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation will be added later
    return Container();
  }
}