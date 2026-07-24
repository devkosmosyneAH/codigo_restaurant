import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return isLoading ? Skeletonizer(enabled: true, child: child) : child;
  }
}

class SkeletonCardPlaceholder extends StatelessWidget {
  const SkeletonCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Bone.text(width: 160),
            const SizedBox(height: 12),
            Bone.text(words: 8),
            const SizedBox(height: 12),
            Bone.text(words: 4),
            const SizedBox(height: 16),
            Row(
              children: [
                Bone.button(
                  width: 96,
                  height: 36,
                  type: BoneButtonType.elevated,
                ),
                const SizedBox(width: 10),
                Bone.button(
                  width: 96,
                  height: 36,
                  type: BoneButtonType.elevated,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonListPlaceholder extends StatelessWidget {
  const SkeletonListPlaceholder({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: itemCount,
        itemBuilder: (context, index) => const SkeletonCardPlaceholder(),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      ),
    );
  }
}
