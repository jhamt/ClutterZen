import 'package:flutter/material.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const items = [
    {'title': 'Bedroom', 'icon': Icons.bed_outlined},
    {'title': 'Kitchen', 'icon': Icons.kitchen_outlined},
    {'title': 'Office', 'icon': Icons.desktop_windows_outlined},
    {'title': 'Closet', 'icon': Icons.checkroom_outlined},
    {'title': 'Garage', 'icon': Icons.garage_outlined},
    {'title': 'Living Room', 'icon': Icons.weekend_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          for (final i in items)
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        CategoryDetailScreen(title: i['title'] as String)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(i['icon'] as IconData,
                        size: 36, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(i['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tips = [
      'Group similar items together',
      'Use bins and labels',
      'Clear surfaces first',
      'Donate unused items',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recommended steps',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final t in tips)
            Card(
              child: ListTile(
                  leading: Icon(Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(t)),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture this room'),
          ),
        ],
      ),
    );
  }
}
