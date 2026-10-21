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
      sites = _visibleSites(result[0] as List<Site>);
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

  List<Site> _visibleSites(List<Site> sites) => List.generate(
    2,
    (index) => index < sites.length ? sites[index] : SiteStore.defaults[index],
  );

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
      final allUpdatedSites = List<Site>.of(storedSites);
      final storedIndex = allUpdatedSites.indexWhere(
        (stored) => stored.url == site.url,
      );
      if (storedIndex < 0) {
        allUpdatedSites.add(updatedSite);
      } else {
        allUpdatedSites[storedIndex] = updatedSite;
      }
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
      updatedSites = _visibleSites(result[1] as List<Site>);
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
