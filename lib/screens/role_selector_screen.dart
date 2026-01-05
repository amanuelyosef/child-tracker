import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';
import '../widgets/logout_dialog.dart';
import 'child_mode_screen.dart';
import 'parent_mode_screen.dart';

/// Role selector screen for choosing between child and parent modes
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade900,
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Soft gradient background with atmosphere
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                  Colors.teal.shade50,
                ],
              ),
            ),
          ),
          // Decorative circles for depth
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100.withValues(alpha: 255 * 0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade100.withValues(alpha: 255 * 0.35),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Child Tracker', style: headline),
                                const SizedBox(height: 6),
                                Text(
                                  'Stay close. Stay safe.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 255 * 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.logout, color: Colors.red.shade400, size: 24),
                                    onPressed: () => LogoutDialog.show(context),
                                    tooltip: 'Sign out',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 255 * 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.my_location, color: Colors.blue, size: 28),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Hero card
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade600, Colors.teal.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200.withValues(alpha: 255 * 0.5),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 255 * 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.satellite_alt, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Real-time GPS safety',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Pick your role to start sharing or monitoring live location with instant alerts.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 255 * 0.9),
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Role cards
                        RoleCard(
                          label: 'Child / Broadcaster',
                          description: 'Share your location securely in the background.',
                          icon: Icons.child_care,
                          color: Colors.blue.shade600,
                          accentColor: Colors.blue.shade100,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChildModeScreen()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        RoleCard(
                          label: 'Parent / Monitor',
                          description: 'View live location, distance, and safety radius.',
                          icon: Icons.shield_moon,
                          color: Colors.teal.shade600,
                          accentColor: Colors.teal.shade100,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ParentModeScreen()),
                          ),
                        ),

                        const SizedBox(height: 20),
                        
                        // Permission info card
                        Card(
                          color: Colors.amber.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.security, color: Colors.amber.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Grant location & notification permissions for best real-time accuracy.',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
