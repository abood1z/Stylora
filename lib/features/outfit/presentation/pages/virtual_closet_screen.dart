import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/models/closet_item_model.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/context_ext.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VirtualClosetScreen extends ConsumerStatefulWidget {
  const VirtualClosetScreen({super.key});

  @override
  ConsumerState<VirtualClosetScreen> createState() =>
      _VirtualClosetScreenState();
}

class _VirtualClosetScreenState extends ConsumerState<VirtualClosetScreen> {
  String? _selectedCategory;
  String? _selectedColor;

  // AI-extracted types from the service
  final List<String> _categories = [
    'Blazer', 'Blouse', 'Capris', 'Cardigan', 'Chinos', 'Coat', 'Crop', 'Culottes', 'Cutoffs', 'Dress', 'Halter', 'Henley', 'Hoodie', 'Jacket', 'Jeans', 'Jersey', 'Joggers', 'Jumpsuit', 'Kimono', 'Leggings', 'Others', 'Pants', 'Parka', 'Poncho', 'Romper', 'Shorts', 'Skirt', 'Sweater', 'Tank', 'Tee', 'Top', 'Trunks', 'Turtleneck',
  ];

  final List<String> _colors = [
    'black',
    'blue',
    'brown',
    'green',
    'grey',
    'orange',
    'pink',
    'purple',
    'red',
    'silver',
    'white',
    'yellow',
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My AI Closet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ClosetItemModel>>(
        // Using StreamBuilder directly as requested to satisfy the architectural constraint
        stream: ref
            .watch(firestoreServiceProvider)
            .watchUserCloset(
              user.uid,
              category: _selectedCategory,
              color: _selectedColor,
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No items found in your closet. Start adding some!'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildItemCard(ClosetItemModel item) {
    return GlassCard(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item.color,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters', style: context.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text('Category', style: context.textTheme.labelMedium),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    hint: const Text('All Categories'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => _selectedCategory = val);
                      setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Color', style: context.textTheme.labelMedium),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedColor,
                    hint: const Text('All Colors'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ..._colors.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => _selectedColor = val);
                      setState(() => _selectedColor = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Center(child: Text('Apply Filters')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
