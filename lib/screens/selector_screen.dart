import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/site_store.dart';
import '../services/url_normalizer.dart';
import '../theme.dart';
import '../widgets/tv_focusable.dart';
import 'remote_test_screen.dart';
import 'web_screen.dart';

class SelectorScreen extends StatefulWidget {
  const SelectorScreen({super.key});

  @override
  State<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> {
  final _store = SiteStore();
  List<Site> _sites = const [];
  bool _loading = true;
  bool _showHintRow = true;
  String? _lastOpenedUrl;
  final List<FocusNode> _cardFocusNodes = [];
  final _editButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadDataAndCheckAutoOpen();
  }

  @override
  void dispose() {
    for (final node in _cardFocusNodes) {
      node.dispose();
    }
    _editButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndCheckAutoOpen() async {
    final sites = await _store.load();
    final lastUrl = await _store.getLastOpenedSite();
    final openLastOnStart = await _store.getOpenLastOnStart();

    if (!mounted) return;

    _cardFocusNodes.clear();
    for (var i = 0; i < sites.length; i++) {
      _cardFocusNodes.add(FocusNode());
    }

    setState(() {
      _sites = sites;
      _lastOpenedUrl = lastUrl;
      _loading = false;
    });

    // Check if auto-open is enabled and valid
    if (openLastOnStart &&
        lastUrl != null &&
        sites.any((s) => s.url == lastUrl)) {
      final targetSite = sites.firstWhere((s) => s.url == lastUrl);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSite(targetSite);
      });
      return;
    }

    _restoreInitialFocus();
  }

  void _restoreInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sites.isEmpty) return;
      int focusIndex = 0;
      if (_lastOpenedUrl != null) {
        final idx = _sites.indexWhere((s) => s.url == _lastOpenedUrl);
        if (idx >= 0) focusIndex = idx;
      }
      if (focusIndex < _cardFocusNodes.length) {
        _cardFocusNodes[focusIndex].requestFocus();
      }
    });
  }

  void _dismissHintRow() {
    if (_showHintRow) {
      setState(() => _showHintRow = false);
    }
  }

  Future<void> _openSite(Site site) async {
    _dismissHintRow();
    await _store.setLastOpenedSite(site.url);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WebScreen(site: site)));
    // Reload state and focus last opened site upon return
    final updatedLastUrl = await _store.getLastOpenedSite();
    final updatedSites = await _store.load();
    if (mounted) {
      setState(() {
        _sites = updatedSites;
        _lastOpenedUrl = updatedLastUrl;
      });
      _restoreInitialFocus();
    }
  }

  Future<void> _openEditor() async {
    _dismissHintRow();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditSitesScreen(sites: _sites, store: _store),
      ),
    );
    final sites = await _store.load();
    if (mounted) {
      _cardFocusNodes.clear();
      for (var i = 0; i < sites.length; i++) {
        _cardFocusNodes.add(FocusNode());
      }
      setState(() {
        _sites = sites;
      });
      _restoreInitialFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: bingeYellow)),
      );
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _dismissHintRow();
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'Binge',
                style: TextStyle(
                  color: bingeYellow,
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a site',
                style: TextStyle(
                  color: bingePurple,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),

              // Cards row (Natural Traversal, no pointless OrderedTraversalPolicy)
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _sites.length; i++) ...[
                        _SiteCard(
                          site: _sites[i],
                          focusNode: i < _cardFocusNodes.length
                              ? _cardFocusNodes[i]
                              : null,
                          onSelected: () => _openSite(_sites[i]),
                          isLastOpened: _sites[i].url == _lastOpenedUrl,
                        ),
                        if (i < _sites.length - 1) const SizedBox(width: 32),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Edit links button
              TvFocusable(
                focusNode: _editButtonFocusNode,
                onSelected: _openEditor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 14,
                ),
                builder: (ctx, focused) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit,
                      color: focused ? bingeYellow : bingePurple,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Edit links',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: focused ? bingeYellow : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Hint row (disappears after first keypress)
              AnimatedOpacity(
                opacity: _showHintRow ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14101E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bingeDeepPurple.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'OK select  ·  Menu options  ·  Back exit',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.onSelected,
    this.focusNode,
    this.isLastOpened = false,
  });

  final Site site;
  final VoidCallback onSelected;
  final FocusNode? focusNode;
  final bool isLastOpened;

  @override
  Widget build(BuildContext context) {
    final faviconUrl = 'https://${site.host}/favicon.ico';

    return TvFocusable(
      focusNode: focusNode,
      onSelected: onSelected,
      borderRadius: 22,
      scaleOnFocus: true,
      scaleValue: 1.08,
      builder: (ctx, focused) {
        return SizedBox(
          width: 320,
          height: 220,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: bingeDeepPurple,
                      child: Text(
                        site.initial,
                        style: const TextStyle(
                          fontSize: 34,
                          color: bingeYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ClipOval(
                      child: Image.network(
                        faviconUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  site.name,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: focused ? bingeYellow : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  site.host,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLastOpened) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bingePurple.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Recent',
                      style: TextStyle(
                        color: bingeYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class EditSitesScreen extends StatefulWidget {
  const EditSitesScreen({required this.sites, required this.store, super.key});
  final List<Site> sites;
  final SiteStore store;

  @override
  State<EditSitesScreen> createState() => _EditSitesScreenState();
}

class _EditSitesScreenState extends State<EditSitesScreen> {
  late final List<TextEditingController> _names;
  late final List<TextEditingController> _urls;
  final _formKey = GlobalKey<FormState>();
  bool _hasUnsavedChanges = false;
  bool _openLastOnStart = false;

  @override
  void initState() {
    super.initState();
    _names = widget.sites
        .map((s) => TextEditingController(text: s.name))
        .toList();
    _urls = widget.sites
        .map((s) => TextEditingController(text: s.url))
        .toList();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final pref = await widget.store.getOpenLastOnStart();
    if (mounted) setState(() => _openLastOnStart = pref);
  }

  @override
  void dispose() {
    for (final controller in [..._names, ..._urls]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addSite() {
    setState(() {
      _names.add(TextEditingController(text: 'New Site'));
      _urls.add(TextEditingController(text: 'https://'));
      _hasUnsavedChanges = true;
    });
  }

  void _deleteSite(int index) {
    if (_names.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one site must remain.')),
      );
      return;
    }
    setState(() {
      _names[index].dispose();
      _urls[index].dispose();
      _names.removeAt(index);
      _urls.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL is required';
    if (!UrlNormalizer.isValid(value)) {
      return 'Enter a valid address (e.g. bingebang.st, httpbin.org, IP)';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final updated = <Site>[];
    for (var i = 0; i < _names.length; i++) {
      final normalized = UrlNormalizer.normalize(_urls[i].text.trim());
      if (normalized != null) {
        updated.add(Site(name: _names[i].text.trim(), url: normalized));
      }
    }
    await widget.store.save(updated);
    await widget.store.setOpenLastOnStart(_openLastOnStart);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14101E),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: bingeYellow),
        ),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TvFocusable(
            autofocus: true,
            onSelected: () => Navigator.of(ctx).pop(true),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            builder: (c, focused) => Text(
              'Discard',
              style: TextStyle(color: focused ? bingeYellow : Colors.white),
            ),
          ),
          TvFocusable(
            onSelected: () => Navigator.of(ctx).pop(false),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            builder: (c, focused) => Text(
              'Keep Editing',
              style: TextStyle(color: focused ? bingeYellow : Colors.white),
            ),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          child: Form(
            key: _formKey,
            onChanged: () => _hasUnsavedChanges = true,
            child: ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit links',
                      style: TextStyle(
                        color: bingeYellow,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TvFocusable(
                      onSelected: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RemoteTestScreen(),
                          ),
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      builder: (ctx, focused) => Row(
                        children: [
                          Icon(
                            Icons.settings_remote,
                            color: focused ? bingeYellow : bingePurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remote Test',
                            style: TextStyle(
                              color: focused ? bingeYellow : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Site rows
                for (var i = 0; i < _names.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Site ${i + 1}',
                        style: const TextStyle(
                          color: bingePurple,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TvFocusable(
                        onSelected: () => _deleteSite(i),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        builder: (ctx, focused) => Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: focused ? bingeYellow : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: focused ? bingeYellow : Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _names[i],
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _urls[i],
                    decoration: const InputDecoration(
                      labelText: 'URL (e.g. bingebang.st, httpbin.org)',
                    ),
                    validator: _validateUrl,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 24),
                ],

                // Add Site button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TvFocusable(
                    onSelected: _addSite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    builder: (ctx, focused) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          color: focused ? bingeYellow : bingePurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Site',
                          style: TextStyle(
                            color: focused ? bingeYellow : Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),

                // Preference: Open last site on start
                TvFocusable(
                  onSelected: () {
                    setState(() {
                      _openLastOnStart = !_openLastOnStart;
                      _hasUnsavedChanges = true;
                    });
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  builder: (ctx, focused) => Row(
                    children: [
                      Icon(
                        _openLastOnStart
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: focused ? bingeYellow : bingePurple,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Open last site on start',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Automatically launches directly into the last visited site upon launch',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Action buttons: Save, Reset to defaults, Cancel
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    TvFocusable(
                      onSelected: _save,
                      backgroundColor: bingeDeepPurple,
                      focusedBackgroundColor: bingePurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      builder: (ctx, focused) => Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: focused ? bingeYellow : Colors.white,
                        ),
                      ),
                    ),
                    TvFocusable(
                      onSelected: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF14101E),
                            title: const Text(
                              'Reset to Defaults?',
                              style: TextStyle(color: bingeYellow),
                            ),
                            content: const Text(
                              'This will reset your sites to BingeBang and Rivestream.',
                            ),
                            actions: [
                              TvFocusable(
                                autofocus: true,
                                onSelected: () => Navigator.of(ctx).pop(true),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                builder: (c, focused) => Text(
                                  'Reset',
                                  style: TextStyle(
                                    color: focused ? bingeYellow : Colors.white,
                                  ),
                                ),
                              ),
                              TvFocusable(
                                onSelected: () => Navigator.of(ctx).pop(false),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                builder: (c, focused) => Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: focused ? bingeYellow : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.store.reset();
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      builder: (ctx, focused) => Text(
                        'Reset to defaults',
                        style: TextStyle(
                          fontSize: 20,
                          color: focused ? bingeYellow : Colors.white70,
                        ),
                      ),
                    ),
                    TvFocusable(
                      onSelected: () async {
                        if (await _onWillPop() && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      builder: (ctx, focused) => Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 20,
                          color: focused ? bingeYellow : Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
