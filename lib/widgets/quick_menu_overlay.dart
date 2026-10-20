import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/tv_focusable.dart';

class QuickMenuOverlay extends StatefulWidget {
  const QuickMenuOverlay({
    super.key,
    required this.onResume,
    required this.onReload,
    required this.onHome,
    required this.onToggleCursorMode,
    required this.isCursorMode,
    required this.currentPageWidth,
    required this.onSelectPageWidth,
    required this.isAdBlockEnabled,
    required this.onToggleAdBlock,
    required this.onAllowRedirectOnce,
    this.pendingBlockedRedirect,
    required this.onOpenRemoteTest,
    required this.onOpenDiagnostics,
    required this.webViewVersion,
  });

  final VoidCallback onResume;
  final VoidCallback onReload;
  final VoidCallback onHome;
  final VoidCallback onToggleCursorMode;
  final bool isCursorMode;
  final int currentPageWidth;
  final ValueChanged<int> onSelectPageWidth;
  final bool isAdBlockEnabled;
  final ValueChanged<bool> onToggleAdBlock;
  final VoidCallback onAllowRedirectOnce;
  final String? pendingBlockedRedirect;
  final VoidCallback onOpenRemoteTest;
  final VoidCallback onOpenDiagnostics;
  final String webViewVersion;

  @override
  State<QuickMenuOverlay> createState() => _QuickMenuOverlayState();
}

class _QuickMenuOverlayState extends State<QuickMenuOverlay> {
  static const _pageWidthOptions = [1024, 1280, 1600, 1920];

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.contextMenu): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onResume();
              return null;
            },
          ),
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          alignment: Alignment.centerRight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = constraints.maxWidth < 600
                  ? constraints.maxWidth
                  : constraints.maxWidth.clamp(420.0, 560.0).toDouble();
              return Container(
                width: panelWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: bingeSurface,
                  border: const Border(
                    left: BorderSide(color: bingeDivider, width: 1),
                  ),
                ),
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: panelWidth < 420 ? 20 : 28,
                      vertical: 28,
                    ),
                    children: [
                  const Text(
                    'Quick Menu',
                    style: TextStyle(
                      color: bingeYellow,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Press Back to resume',
                    style: bingeSecondaryText,
                  ),
                  const SizedBox(height: 24),

                  if (widget.pendingBlockedRedirect != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bingeRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: bingeYellow, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Blocked Redirect:',
                            style: TextStyle(
                              color: bingeYellow,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.pendingBlockedRedirect!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          TvFocusable(
                            onSelected: widget.onAllowRedirectOnce,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            builder: (ctx, focused) => Text(
                              'Allow this redirect once',
                              style: TextStyle(
                                color: focused ? bingeYellow : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildMenuItem(
                    autofocus: true,
                    icon: Icons.play_arrow,
                    label: 'Resume',
                    onTap: widget.onResume,
                  ),
                  _buildMenuItem(
                    icon: Icons.refresh,
                    label: 'Reload',
                    onTap: widget.onReload,
                  ),
                  _buildMenuItem(
                    icon: Icons.home,
                    label: 'Home (Sites)',
                    onTap: widget.onHome,
                  ),
                  _buildMenuItem(
                    icon: widget.isCursorMode ? Icons.mouse : Icons.gamepad,
                    label: widget.isCursorMode
                        ? 'Switch to Focus Mode'
                        : 'Switch to Cursor Mode',
                    subtitle: 'Long-press OK or Red button',
                    onTap: widget.onToggleCursorMode,
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text(
                    'Page Width / Zoom',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _pageWidthOptions.map((w) {
                      final isSelected = widget.currentPageWidth == w;
                      return TvFocusable(
                        scaleOnFocus: true,
                        scaleValue: 1.05,
                        onSelected: () => widget.onSelectPageWidth(w),
                        focusedBorderColor: bingeYellow,
                        unfocusedBorderColor: isSelected
                            ? bingePurple
                            : Colors.white24,
                        backgroundColor: isSelected
                            ? bingeDeepPurple
                            : const Color(0xFF1E1B29),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        builder: (ctx, focused) => Text(
                          '$w px',
                          style: TextStyle(
                            color: focused
                                ? bingeYellow
                                : (isSelected ? bingeYellow : Colors.white),
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  _buildMenuItem(
                    icon: widget.isAdBlockEnabled
                        ? Icons.shield
                        : Icons.shield_outlined,
                    label: 'Block popups & ads',
                    subtitle: widget.isAdBlockEnabled
                        ? 'Enabled (blocking known ad hosts)'
                        : 'Disabled',
                    onTap: () =>
                        widget.onToggleAdBlock(!widget.isAdBlockEnabled),
                  ),

                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.settings_remote,
                    label: 'Remote Test & Diagnostics',
                    subtitle: 'Verify keycodes and hardware delivery',
                    onTap: widget.onOpenRemoteTest,
                  ),
                  _buildMenuItem(
                    icon: Icons.health_and_safety,
                    label: 'Diagnostics',
                    subtitle: 'WebView and loading report',
                    onTap: widget.onOpenDiagnostics,
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bingeBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bingeDivider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About Binge',
                          style: TextStyle(
                            color: bingeYellow,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'App Version: 1.0.0 (Fire OS 8 / Android 11 API 30)',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'WebView: ${widget.webViewVersion}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TvFocusable(
        autofocus: autofocus,
        onSelected: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        builder: (ctx, focused) => Row(
          children: [
            Icon(icon, color: focused ? bingeYellow : bingePurple, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: focused ? bingeYellow : Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
