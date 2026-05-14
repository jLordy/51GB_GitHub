import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

/// Shows connected family/care-team members and their sync status.
///
/// Reads from [acceptedConnectionsProvider] — the same source used by
/// FolderDocumentsScreen and DocumentsScreen for connection guards.
class FamilySyncStatus extends ConsumerWidget {
  const FamilySyncStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
    final connectionsAsync = ref.watch(acceptedConnectionsProvider);

    return GlassmorphicContainer(
      child: connectionsAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (connections) {
          if (connections.isEmpty) {
            return _EmptyConnections(cs: cs, tt: tt);
          }
          return _ConnectedRow(
            connections: connections,
            currentUid: currentUid,
            cs: cs,
            tt: tt,
          );
        },
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(Icons.people_outline, color: cs.onSurfaceVariant, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No family members connected yet',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        GestureDetector(
          onTap: () => context.go('/connections'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Palette.greenColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Connect',
              style: tt.labelSmall?.copyWith(
                color: Palette.greenColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Connected row ───────────────────────────────────────────────────────────

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({
    required this.connections,
    required this.currentUid,
    required this.cs,
    required this.tt,
  });
  final List connections;
  final String currentUid;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Label
        Text(
          'Family',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),

        // Overlapping avatar circles — up to 3 shown
        SizedBox(
          height: 34,
          width: (connections.length.clamp(1, 3) * 26 + 8).toDouble(),
          child: Stack(
            children: <Widget>[
              for (int i = 0; i < connections.length.clamp(0, 3); i++)
                Positioned(
                  left: i * 24.0,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.greenColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Palette.greenColor.withValues(alpha: 0.40),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Palette.greenColor,
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (connections.length > 3) ...<Widget>[
          const SizedBox(width: 4),
          Text(
            '+${connections.length - 3}',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],

        const Spacer(),

        GestureDetector(
          onTap: () => context.go('/connections'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Palette.greenColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'View',
              style: tt.labelSmall?.copyWith(
                color: Palette.greenColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
