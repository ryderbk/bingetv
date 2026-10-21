import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../services/site_store.dart';
import '../services/key_pipeline.dart';
import '../services/url_normalizer.dart';
import '../theme.dart';
import '../widgets/tv_focusable.dart';
import 'web_screen.dart';
import '../widgets/tv_text_field.dart';

class SelectorScreen extends StatefulWidget {
  const SelectorScreen({this.webScreenBuilder, super.key});

  final Widget Function(Site site)? webScreenBuilder;

  @override
  State<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> {
  final _store = SiteStore();
  List<Site> _sites = const [];
  bool _loading = true;
  String? _lastOpenedUrl;
  bool _openingSite = false;
  final List<FocusNode> _cardFocusNodes = [];
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    KeyPipeline.instance.setMode(InputMode.selector);
    FocusManager.instance.addListener(_recoverSelectorFocus);
    _loadDataAndCheckAutoOpen();
  }

  @override
  void dispose() {
    for (final node in _cardFocusNodes) {
      node.dispose();
    }
    _loadTimeoutTimer?.cancel();
    FocusManager.instance.removeListener(_recoverSelectorFocus);
    super.dispose();
  }

  void _recoverSelectorFocus() {
    if (!mounted || _loading || _sites.isEmpty) return;
    if (FocusManager.instance.primaryFocus != null) return;
    _restoreInitialFocus();
  }

  Future<void> _loadDataAndCheckAutoOpen() async {
    List<Site> sites = SiteStore.defaults;
    String? lastUrl;
    var openLastOnStart = false;
    try {
      final result = await _loadPreferencesWithTimeout();
      sites = (result[0] as List<Site>).take(2).toList();
      lastUrl = result[1] as String?;
      openLastOnStart = result[2] as bool;
    } catch (_) {
      // Defaults keep the selector usable when preferences are unavailable.
    }

    if (!mounted) return;

    _syncCardFocusNodes(sites);
    setState(() {
      _sites = sites;
      _lastOpenedUrl = lastUrl;
      _loading = false;
    });
    if (openLastOnStart &&
        lastUrl != null &&
        sites.any((site) => site.url == lastUrl)) {
      _openSite(sites.firstWhere((site) => site.url == lastUrl));
    } else {
      _restoreInitialFocus();
    }
  }

  void _syncCardFocusNodes(List<Site> sites) {
    final oldNodes = List<FocusNode>.of(_cardFocusNodes);
    for (var i = sites.length; i < oldNodes.length; i++) {
      oldNodes[i].dispose();
    }
    _cardFocusNodes
      ..clear()
      ..addAll(
        List.generate(
          sites.length,
          (index) => index < oldNodes.length
              ? oldNodes[index]
              : FocusNode(debugLabel: 'site-$index'),
        ),
      );
  }

  Future<List<dynamic>> _loadPreferencesWithTimeout() {
    final completer = Completer<List<dynamic>>();
    void finish(List<dynamic> value) {
      if (!completer.isCompleted) {
        _loadTimeoutTimer?.cancel();
        completer.complete(value);
      }
    }

    Future.wait([
      _store.load(),
      _store.getLastOpenedSite(),
      _store.getOpenLastOnStart(),
    ]).then(
      finish,
      onError: (_) => finish([SiteStore.defaults, null, false]),
    );
    _loadTimeoutTimer = Timer(
      const Duration(seconds: 3),
      () => finish([SiteStore.defaults, null, false]),
    );
    return completer.future;
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

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL is required';
    if (!UrlNormalizer.isValid(value)) {
      return 'Enter a valid website address.';
    }
    return null;
  }

  int _focusedSiteIndex() {
    final index = _cardFocusNodes.indexWhere((node) => node.hasFocus);
    return index < 0 ? 0 : index;
  }

  Future<void> _editFocusedSite() async {
    if (_sites.isEmpty) return;
    final index = _focusedSiteIndex();
    final site = _sites[index];
    final nameController = TextEditingController(text: site.name);
    final urlController = TextEditingController(text: site.url);
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit ${site.name}', style: bingeScreenTitle),
          content: SizedBox(
            width: (MediaQuery.sizeOf(dialogContext).width * 0.8)
                .clamp(280.0, 560.0)
                .toDouble(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvTextField(
                  label: 'Website name',
                  controller: nameController,
                  onChanged: () => setDialogState(() => error = null),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: bingeSpace4),
                TvTextField(
                  label: 'Website URL',
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  onChanged: () => setDialogState(() => error = null),
                  validator: _validateUrl,
                ),
                if (error != null) ...[
                  const SizedBox(height: bingeSpace3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: const TextStyle(color: bingeDanger, fontSize: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TvFocusable(
              autofocus: true,
              onSelected: () {
                final normalizedUrl = UrlNormalizer.normalize(urlController.text);
                if (nameController.text.trim().isEmpty || normalizedUrl == null) {
                  setDialogState(() {
                    error = nameController.text.trim().isEmpty
                        ? 'Enter a website name.'
                        : 'Enter a valid website URL.';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              builder: (_, focused) => Text(
                'Save',
                style: TextStyle(
                  color: focused ? bingeYellow : Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            TvFocusable(
              onSelected: () => Navigator.of(dialogContext).pop(false),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              builder: (_, focused) => Text(
                'Cancel',
                style: TextStyle(
                  color: focused ? bingeYellow : bingeTextSecondary,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final normalizedUrl = UrlNormalizer.normalize(urlController.text)!;
      final updatedSite = site.copyWith(
        name: nameController.text.trim(),
        url: normalizedUrl,
      );
      final storedSites = await _store.load();
      final allUpdatedSites = storedSites
          .map((stored) => stored.url == site.url ? updatedSite : stored)
          .toList();
      final updatedSites = List<Site>.of(_sites)..[index] = updatedSite;
      await _store.save(allUpdatedSites);
      if (_lastOpenedUrl == site.url) {
        await _store.setLastOpenedSite(normalizedUrl);
      }
      if (mounted) {
        setState(() {
          _sites = updatedSites;
          if (_lastOpenedUrl == site.url) _lastOpenedUrl = normalizedUrl;
        });
      }
    }

    nameController.dispose();
    urlController.dispose();
    if (mounted) _cardFocusNodes[index].requestFocus();
  }

  Future<void> _openSite(Site site) async {
    if (_openingSite) return;
    setState(() => _openingSite = true);
    unawaited(
      _store.setLastOpenedSite(site.url).catchError((error, stackTrace) {
        debugPrint('Binge: failed to save last opened site: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              widget.webScreenBuilder?.call(site) ?? WebScreen(site: site),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingSite = false);
    }
    // Reload state and focus last opened site upon return
    String? updatedLastUrl;
    List<Site> updatedSites = _sites;
    try {
      final result = await Future.wait([
        _store.getLastOpenedSite(),
        _store.load(),
      ]).timeout(const Duration(seconds: 3));
      updatedLastUrl = result[0] as String?;
      updatedSites = (result[1] as List<Site>).take(2).toList();
    } catch (_) {}
    if (mounted) {
      _syncCardFocusNodes(updatedSites);
      setState(() {
        _sites = updatedSites;
        _lastOpenedUrl = updatedLastUrl ?? _lastOpenedUrl;
      });
      _restoreInitialFocus();
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bingeBackground,
        body: Center(child: CircularProgressIndicator(color: bingeYellow)),
      );
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.contextMenu) {
          _editFocusedSite();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: bingeBackground,
        body: SafeArea(
          minimum: bingePageInsets(MediaQuery.sizeOf(context).width, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: bingeSpace4),
              const Text(
                'Binge',
                style: TextStyle(
                  color: bingeYellow,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: bingeSpace2),
              const Text('Choose a site', style: bingeSecondaryText),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final profileCount = _sites.length;
                      const gap = 28.0;
                      final maxColumns = profileCount.clamp(1, 4).toInt();
                      final columns = ((constraints.maxWidth + gap) /
                              (116 + gap))
                          .floor()
                          .clamp(1, maxColumns)
                          .toInt();
                      final maxItemWidth =
                          (constraints.maxHeight - 72).clamp(116.0, 252.0);
                      final itemWidth = ((constraints.maxWidth -
                                  gap * (columns - 1)) /
                              columns)
                          .clamp(116.0, maxItemWidth)
                          .toDouble();
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            runAlignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: gap,
                            runSpacing: bingeSpace6,
                            children: [
                              for (var i = 0; i < _sites.length; i++)
                                _SiteCard(
                                  site: _sites[i],
                                  width: itemWidth,
                                  focusNode: i < _cardFocusNodes.length
                                      ? _cardFocusNodes[i]
                                      : null,
                                  onSelected: () => _openSite(_sites[i]),
                                  isLastOpened:
                                      _sites[i].url == _lastOpenedUrl,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
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
    required this.width,
    this.focusNode,
    this.isLastOpened = false,
  });

  final Site site;
  final VoidCallback onSelected;
  final double width;
  final FocusNode? focusNode;
  final bool isLastOpened;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onSelected: onSelected,
      borderRadius: width,
      scaleOnFocus: false,
      backgroundColor: Colors.transparent,
      focusedBorderColor: Colors.transparent,
      unfocusedBorderColor: Colors.transparent,
      borderWidth: 0,
      builder: (ctx, focused) {
        final avatarSize = width * 0.62;
        return SizedBox(
          width: width,
          height: width + 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOutCubic,
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: focused ? bingeRaised : bingeSurface,
                  border: Border.all(
                    color: focused ? bingeYellow : bingeDivider,
                    width: focused ? 3 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    site.initial,
                    style: TextStyle(
                      fontSize: avatarSize * 0.36,
                      color: focused ? bingeYellow : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                site.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: focused ? bingeYellow : Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isLastOpened) ...[
                const SizedBox(height: 7),
                const Text(
                  'RECENT',
                  style: TextStyle(
                    color: bingeYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
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
  String? _saveError;

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
    for (var i = 0; i < _names.length; i++) {
      if (_names[i].text.trim().isEmpty) {
        setState(() => _saveError = 'Site ${i + 1}: enter a name.');
        return;
      }
      final urlError = _validateUrl(_urls[i].text);
      if (urlError != null) {
        setState(() => _saveError = 'Site ${i + 1} URL: $urlError');
        return;
      }
    }

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
        backgroundColor: bingeBackground,
        body: SafeArea(
          minimum: bingePageInsets(
            MediaQuery.sizeOf(context).width,
            vertical: 24,
          ),
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_hasUnsavedChanges || _saveError != null) {
                setState(() {
                  _hasUnsavedChanges = true;
                  _saveError = null;
                });
              }
            },
            child: ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit links', style: bingeScreenTitle),
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
                const SizedBox(height: 24),

                // Site rows
                for (var i = 0; i < _names.length; i++) ...[
                  Row(
                    key: ValueKey('site-row-$i'),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: bingeYellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Site ${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                              'Remove',
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
                  TvTextField(
                    key: ValueKey('site-name-$i'),
                    label: 'Name',
                    controller: _names[i],
                    onChanged: () {
                      if (!_hasUnsavedChanges || _saveError != null) {
                        setState(() {
                          _hasUnsavedChanges = true;
                          _saveError = null;
                        });
                      }
                    },
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TvTextField(
                    key: ValueKey('site-url-$i'),
                    label: 'URL',
                    controller: _urls[i],
                    onChanged: () {
                      if (!_hasUnsavedChanges || _saveError != null) {
                        setState(() {
                          _hasUnsavedChanges = true;
                          _saveError = null;
                        });
                      }
                    },
                    keyboardType: TextInputType.url,
                    validator: _validateUrl,
                  ),
                  const SizedBox(height: 28),
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
                const Divider(color: bingeDivider),
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
                    horizontal: 18,
                    vertical: 16,
                  ),
                  backgroundColor: bingeSurface,
                  borderRadius: 12,
                  builder: (ctx, focused) => Row(
                    children: [
                      Icon(
                        _openLastOnStart
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        color: focused || _openLastOnStart
                            ? bingeYellow
                            : bingeTextTertiary,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
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
                              _openLastOnStart
                                  ? 'Enabled · resumes your most recent site'
                                  : 'Disabled · show the site selector on launch',
                              style: const TextStyle(
                                fontSize: 16,
                                color: bingeTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                if (_saveError != null) ...[
                  Text(
                    _saveError!,
                    style: const TextStyle(color: bingeDanger, fontSize: 16),
                  ),
                  const SizedBox(height: bingeSpace3),
                ],

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
