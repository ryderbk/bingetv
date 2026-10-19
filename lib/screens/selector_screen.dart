import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/site_store.dart';
import '../theme.dart';
import 'web_screen.dart';

class SelectorScreen extends StatefulWidget {
  const SelectorScreen({super.key});

  @override
  State<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> {
  final _store = SiteStore();
  final _firstFocus = FocusNode();
  List<Site> _sites = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    final sites = await _store.load();
    if (mounted) {
      setState(() {
        _sites = sites;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _firstFocus.requestFocus();
      });
    }
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditSitesScreen(sites: _sites, store: _store)),
    );
    await _loadSites();
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: bingeYellow)));
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(48),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Binge', style: TextStyle(color: bingeYellow, fontSize: 52, fontWeight: FontWeight.bold)),
            const Text('Choose a site', style: TextStyle(color: bingePurple, fontSize: 26)),
            const Spacer(),
            FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 32,
                runSpacing: 24,
                children: [
                  for (var i = 0; i < _sites.length; i++)
                    _SiteCard(
                      site: _sites[i],
                      focusNode: i == 0 ? _firstFocus : null,
                      onSelected: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => WebScreen(site: _sites[i])),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _TvButton(label: 'Edit links', onPressed: _openEditor),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SiteCard extends StatefulWidget {
  const _SiteCard({required this.site, required this.onSelected, this.focusNode});
  final Site site;
  final VoidCallback onSelected;
  final FocusNode? focusNode;

  @override
  State<_SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends State<_SiteCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      child: GestureDetector(
        onTap: widget.onSelected,
        child: AnimatedScale(
          scale: _focused ? 1.08 : 1,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 280,
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0A12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _focused ? bingeYellow : bingeDeepPurple, width: _focused ? 4 : 2),
              boxShadow: _focused ? [const BoxShadow(color: bingePurple, blurRadius: 24)] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 34, backgroundColor: bingeDeepPurple, child: Text(widget.site.initial, style: const TextStyle(fontSize: 34, color: bingeYellow))),
                const SizedBox(height: 12),
                Text(widget.site.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(widget.site.host, style: const TextStyle(fontSize: 20, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvButton extends StatefulWidget {
  const _TvButton({required this.label, required this.onPressed, this.secondary = false});
  final String label;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.secondary ? Colors.transparent : bingeDeepPurple,
              border: Border.all(color: _focused ? bingeYellow : bingePurple, width: _focused ? 3 : 2),
            ),
            child: Text(widget.label, style: TextStyle(fontSize: 24, color: _focused ? bingeYellow : Colors.white)),
          ),
        ),
      );
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

  @override
  void initState() {
    super.initState();
    _names = widget.sites.map((site) => TextEditingController(text: site.name)).toList();
    _urls = widget.sites.map((site) => TextEditingController(text: site.url)).toList();
  }

  @override
  void dispose() {
    for (final controller in [..._names, ..._urls]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL is required';
    final url = Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
    if (url == null || url.host.isEmpty || !['http', 'https'].contains(url.scheme)) return 'Enter a valid web address';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sites = <Site>[];
    for (var i = 0; i < _names.length; i++) {
      var url = _urls[i].text.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      sites.add(Site(name: _names[i].text.trim(), url: url));
    }
    await widget.store.save(sites);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.all(48),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text('Edit links', style: TextStyle(color: bingeYellow, fontSize: 42, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                for (var i = 0; i < _names.length; i++) ...[
                  Text('Site ${i + 1}', style: const TextStyle(color: bingePurple, fontSize: 26)),
                  TextFormField(controller: _names[i], decoration: const InputDecoration(labelText: 'Name'), validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null, textInputAction: TextInputAction.next),
                  const SizedBox(height: 14),
                  TextFormField(controller: _urls[i], decoration: const InputDecoration(labelText: 'URL'), validator: _validateUrl, keyboardType: TextInputType.url, textInputAction: TextInputAction.next),
                  const SizedBox(height: 22),
                ],
                Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    _TvButton(label: 'Save', onPressed: _save),
                    _TvButton(
                      label: 'Reset to defaults',
                      secondary: true,
                      onPressed: () async {
                        await widget.store.reset();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                    ),
                    _TvButton(label: 'Cancel', secondary: true, onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
