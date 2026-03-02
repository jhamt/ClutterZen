import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/professional_service.dart';
import '../../../models/recommendation_context.dart';
import '../../../models/vision_models.dart';
import '../../../services/firebase_functions_service.dart';
import '../../../services/i18n_service.dart';
import '../../payment/book_service_screen.dart';

class ProfessionalTab extends StatefulWidget {
  const ProfessionalTab({
    super.key,
    this.analysis,
    this.embedded = false,
    this.recommendationContext,
  });

  final VisionAnalysis? analysis;
  final bool embedded;
  final RecommendationContext? recommendationContext;

  @override
  State<ProfessionalTab> createState() => _ProfessionalTabState();
}

class _ProfessionalTabState extends State<ProfessionalTab>
    with AutomaticKeepAliveClientMixin {
  static const String _manualLocationPrefsKey =
      'professional_tab_manual_location_query';
  static const String _resultsCachePrefsKey =
      'professional_tab_results_cache_v1';
  static const String _lastSignaturePrefsKey =
      'professional_tab_last_signature_v1';
  static const int _defaultRadiusMeters = 15000;
  static const Duration _resultsCacheTtl = Duration(minutes: 45);
  static const int _maxCachedEntries = 8;
  static final Map<String, _ProfessionalResultsCacheEntry> _sessionCache =
      <String, _ProfessionalResultsCacheEntry>{};
  static String? _sessionLastSignature;

  final FirebaseFunctionsService _functionsService = FirebaseFunctionsService();

  bool _isBootstrapped = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _manualLocationQuery;
  List<ProfessionalService> _professionals = const <ProfessionalService>[];
  NearbyProfessionalsMeta? _meta;
  String? _lastLoadedSignature;
  Future<void>? _activeLoad;
  final Map<String, _ProfessionalResultsCacheEntry> _resultsCache =
      <String, _ProfessionalResultsCacheEntry>{};

  @override
  void initState() {
    super.initState();
    if (_sessionCache.isNotEmpty) {
      _resultsCache.addAll(_sessionCache);
      final sessionSignature = _sessionLastSignature;
      if (sessionSignature != null && sessionSignature.isNotEmpty) {
        final entry = _getCacheEntry(sessionSignature);
        if (entry != null) {
          _isBootstrapped = true;
          _isLoading = false;
          _errorMessage = null;
          _professionals = entry.services;
          _meta = entry.meta;
          _lastLoadedSignature = sessionSignature;
        }
      }
    }
    _bootstrap();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final storedQuery = prefs.getString(_manualLocationPrefsKey);
    _restoreCachedResults(prefs.getString(_resultsCachePrefsKey));
    await _persistCachedResults();
    final lastSignature = prefs.getString(_lastSignaturePrefsKey)?.trim();
    final cachedLast = (lastSignature == null || lastSignature.isEmpty)
        ? null
        : _getCacheEntry(lastSignature);
    if (!mounted) return;
    setState(() {
      _manualLocationQuery =
          storedQuery?.trim().isNotEmpty == true ? storedQuery!.trim() : null;
      _isBootstrapped = true;
      if (cachedLast != null) {
        _isLoading = false;
        _errorMessage = null;
        _professionals = cachedLast.services;
        _meta = cachedLast.meta;
        _lastLoadedSignature = lastSignature;
      }
    });
    if (cachedLast == null && _professionals.isEmpty) {
      await _loadProfessionals();
    }
  }

  void _restoreCachedResults(String? rawJson) {
    _resultsCache
      ..clear()
      ..addEntries(_decodeCacheEntries(rawJson).entries);
    _pruneExpiredCacheEntries();
  }

  Map<String, _ProfessionalResultsCacheEntry> _decodeCacheEntries(
    String? rawJson,
  ) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, _ProfessionalResultsCacheEntry>{};
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return <String, _ProfessionalResultsCacheEntry>{};
      }
      final cache = <String, _ProfessionalResultsCacheEntry>{};
      decoded.forEach((signature, value) {
        if (signature.trim().isEmpty || value is! Map<String, dynamic>) return;
        final entry = _ProfessionalResultsCacheEntry.fromJson(value);
        if (entry != null) {
          cache[signature] = entry;
        }
      });
      return cache;
    } catch (_) {
      return <String, _ProfessionalResultsCacheEntry>{};
    }
  }

  Future<void> _persistCachedResults() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      for (final entry in _resultsCache.entries)
        entry.key: entry.value.toJson(),
    };
    await prefs.setString(_resultsCachePrefsKey, jsonEncode(payload));
  }

  void _pruneExpiredCacheEntries() {
    _resultsCache.removeWhere(
      (_, entry) => !_isCacheEntryFresh(entry),
    );
    if (_resultsCache.length <= _maxCachedEntries) return;
    final ordered = _resultsCache.entries.toList()
      ..sort((left, right) =>
          left.value.savedAtMs.compareTo(right.value.savedAtMs));
    final removeCount = _resultsCache.length - _maxCachedEntries;
    for (int index = 0; index < removeCount; index++) {
      _resultsCache.remove(ordered[index].key);
    }
  }

  bool _isCacheEntryFresh(_ProfessionalResultsCacheEntry entry) {
    final ageMs = DateTime.now().millisecondsSinceEpoch - entry.savedAtMs;
    return ageMs <= _resultsCacheTtl.inMilliseconds;
  }

  void _putCacheEntry({
    required String signature,
    required List<ProfessionalService> services,
    required NearbyProfessionalsMeta? meta,
  }) {
    _resultsCache[signature] = _ProfessionalResultsCacheEntry(
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
      services: services,
      meta: meta,
    );
    _pruneExpiredCacheEntries();
    _sessionCache
      ..clear()
      ..addEntries(_resultsCache.entries);
    _sessionLastSignature = signature;
  }

  _ProfessionalResultsCacheEntry? _getCacheEntry(String signature) {
    final entry = _resultsCache[signature];
    if (entry == null) return null;
    if (!_isCacheEntryFresh(entry)) {
      _resultsCache.remove(signature);
      return null;
    }
    return entry;
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _buildContextSignature() {
    final objects = _detectedObjects()
        .map(_normalizeToken)
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final labels = _labels()
        .map(_normalizeToken)
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final clutter = (_clutterScore() ?? 0).round();
    final locale = I18nService.currentLocale.languageCode.toLowerCase();
    return [
      'locale:$locale',
      'clutter:$clutter',
      'objects:${objects.take(12).join(',')}',
      'labels:${labels.take(10).join(',')}',
    ].join('|');
  }

  String _buildLookupSignature(_ResolvedLookupLocation location) {
    final locationSignature = location.locationQuery != null
        ? 'manual:${_normalizeToken(location.locationQuery!)}'
        : 'gps:${location.latitude!.toStringAsFixed(2)},${location.longitude!.toStringAsFixed(2)}';
    return [
      locationSignature,
      'radius:$_defaultRadiusMeters',
      _buildContextSignature(),
    ].join('|');
  }

  List<String> _detectedObjects() {
    final context = widget.recommendationContext;
    if (context != null && context.objectDetections.isNotEmpty) {
      return context.objectDetections
          .map((entry) => entry.name)
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false);
    }
    if (widget.analysis != null) {
      return widget.analysis!.objects
          .map((entry) => entry.name)
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  List<String> _labels() {
    final context = widget.recommendationContext;
    if (context != null && context.labels.isNotEmpty) {
      return context.labels;
    }
    if (widget.analysis != null && widget.analysis!.labels.isNotEmpty) {
      return widget.analysis!.labels;
    }
    return const <String>[];
  }

  double? _clutterScore() {
    final context = widget.recommendationContext;
    if (context != null) {
      return context.clutterScore;
    }
    if (widget.analysis == null) return null;
    return (widget.analysis!.objects.length * 10.0).clamp(0.0, 100.0);
  }

  Future<_ResolvedLookupLocation?> _resolveLookupLocation({
    required bool forceManual,
  }) async {
    if (!forceManual) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
            return _ResolvedLookupLocation.gps(
              latitude: position.latitude,
              longitude: position.longitude,
            );
          }
        }
      } catch (_) {
        // Fall through to manual location if available.
      }
    }

    final query = _manualLocationQuery?.trim() ?? '';
    if (query.isNotEmpty) {
      return _ResolvedLookupLocation.manual(query);
    }
    return null;
  }

  Future<void> _loadProfessionals({
    bool forceManual = false,
    bool forceRefresh = false,
  }) async {
    if (!_isBootstrapped) return;
    if (_activeLoad != null) {
      await _activeLoad;
      return;
    }

    final task = _performLoadProfessionals(
      forceManual: forceManual,
      forceRefresh: forceRefresh,
    );
    _activeLoad = task;
    try {
      await task;
    } finally {
      if (identical(_activeLoad, task)) {
        _activeLoad = null;
      }
    }
  }

  Future<void> _performLoadProfessionals({
    required bool forceManual,
    required bool forceRefresh,
  }) async {
    final location = await _resolveLookupLocation(forceManual: forceManual);
    if (location == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _professionals = const <ProfessionalService>[];
        _errorMessage = I18nService.translate(
          "Location is required to find verified nearby professionals.",
        );
        _meta = null;
      });
      return;
    }

    final signature = _buildLookupSignature(location);
    if (!forceRefresh) {
      final cachedEntry = _getCacheEntry(signature);
      if (cachedEntry != null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _professionals = cachedEntry.services;
          _meta = cachedEntry.meta;
          _lastLoadedSignature = signature;
        });
        _sessionLastSignature = signature;
        return;
      }

      final hasFreshState = _lastLoadedSignature == signature &&
          _errorMessage == null &&
          _professionals.isNotEmpty;
      if (hasFreshState) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _sessionLastSignature = signature;
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _functionsService.getNearbyProfessionalsViaFunction(
        detectedObjects: _detectedObjects(),
        labels: _labels(),
        clutterScore: _clutterScore(),
        latitude: location.latitude,
        longitude: location.longitude,
        locationQuery: location.locationQuery,
        radiusMeters: _defaultRadiusMeters,
        localeCode: I18nService.currentLocale.languageCode,
        limit: 8,
      );

      _putCacheEntry(
        signature: signature,
        services: response.services,
        meta: response.meta,
      );
      await _persistCachedResults();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSignaturePrefsKey, signature);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _professionals = response.services;
        _meta = response.meta;
        _lastLoadedSignature = signature;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _professionals = const <ProfessionalService>[];
        _meta = null;
        _errorMessage = I18nService.translate(
          "Unable to load nearby professional services right now.",
        );
      });
    }
  }

  Future<void> _promptManualLocation() async {
    final controller = TextEditingController(text: _manualLocationQuery ?? '');
    final query = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(I18nService.translate("Set your location")),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: I18nService.translate("Enter city or ZIP code"),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(I18nService.translate("Cancel")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(I18nService.translate("Save")),
            ),
          ],
        );
      },
    );

    if (query == null) return;
    final normalized = query.trim();
    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(_manualLocationPrefsKey);
      if (!mounted) return;
      setState(() => _manualLocationQuery = null);
      return;
    }

    await prefs.setString(_manualLocationPrefsKey, normalized);
    if (!mounted) return;
    setState(() => _manualLocationQuery = normalized);
    await _loadProfessionals(forceManual: true, forceRefresh: true);
  }

  Future<void> _bookService(ProfessionalService professional) async {
    if (professional.stripeAccountId != null) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => BookServiceScreen(professional: professional),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(I18nService.translate("Service booked successfully!")),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18nService.translate("Direct Booking"),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18nService.translate(
                    "This provider does not support in-app payments yet. Contact them directly to book.",
                  ),
                ),
                const SizedBox(height: 12),
                _SheetAction(
                  icon: Icons.phone,
                  label: I18nService.translate("Call"),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _launchPhone(professional.phone);
                  },
                ),
                _SheetAction(
                  icon: Icons.directions,
                  label: I18nService.translate("Directions"),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _launchExternalUrl(
                      professional.mapsUrl,
                      I18nService.translate("Unable to open directions."),
                    );
                  },
                ),
                _SheetAction(
                  icon: Icons.language,
                  label: I18nService.translate("Visit Website"),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _launchExternalUrl(
                      professional.website,
                      I18nService.translate("Unable to open website."),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Uri? _parseExternalUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    if (uri.host.trim().isEmpty) return null;
    return uri;
  }

  Future<void> _launchPhone(String? phone) async {
    final value = phone?.trim() ?? '';
    if (value.isEmpty) {
      _showSnack(I18nService.translate("Phone number unavailable."));
      return;
    }
    final uri = Uri.parse('tel:${Uri.encodeComponent(value)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    _showSnack(I18nService.translate("Unable to start a phone call."));
  }

  Future<void> _launchExternalUrl(String? rawUrl, String failureMessage) async {
    final uri = _parseExternalUrl(rawUrl);
    if (uri == null) {
      _showSnack(I18nService.translate("Invalid link."));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showSnack(failureMessage);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBanner() {
    final resolved = _meta?.resolvedLocation;
    final label = resolved?['label']?.toString();
    if ((label ?? '').isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE7D7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${I18nService.translate("Nearby results for")} $label',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                I18nService.translate(
                  "Unable to load professional services.",
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _loadProfessionals(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(I18nService.translate("Retry")),
              ),
              OutlinedButton.icon(
                onPressed: _promptManualLocation,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: Text(I18nService.translate("Change location")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final reason = _meta?.reason;
    final message = reason == 'no_verified_results'
        ? I18nService.translate(
            "No high-trust nearby organizers were found for this area.",
          )
        : I18nService.translate("No professional services available");
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _loadProfessionals(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(I18nService.translate("Retry")),
              ),
              OutlinedButton.icon(
                onPressed: _promptManualLocation,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: Text(I18nService.translate("Change location")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_isBootstrapped || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    if (_professionals.isEmpty) {
      return _buildEmptyState();
    }

    final showBanner =
        (_meta?.resolvedLocation?['label']?.toString() ?? '').trim().isNotEmpty;
    final bannerOffset = showBanner ? 1 : 0;

    return ListView.builder(
      shrinkWrap: widget.embedded,
      primary: !widget.embedded,
      physics: widget.embedded
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _professionals.length + bannerOffset,
      itemBuilder: (context, index) {
        if (showBanner && index == 0) {
          return _buildBanner();
        }
        final professional = _professionals[index - bannerOffset];
        return _ProfessionalCard(
          professional: professional,
          onBook: () => _bookService(professional),
          onCall: () => _launchPhone(professional.phone),
          onEmail: () async {
            final email = professional.email?.trim() ?? '';
            if (email.isEmpty) {
              _showSnack(I18nService.translate("Email unavailable."));
              return;
            }
            final uri = Uri.parse(
              'mailto:$email?subject=Organization Service Inquiry',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              return;
            }
            _showSnack(I18nService.translate("Unable to compose email."));
          },
          onDirections: () => _launchExternalUrl(
            professional.mapsUrl,
            I18nService.translate("Unable to open directions."),
          ),
          onWebsite: () => _launchExternalUrl(
            professional.website,
            I18nService.translate("Unable to open website."),
          ),
        );
      },
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({
    required this.professional,
    required this.onBook,
    required this.onCall,
    required this.onEmail,
    required this.onDirections,
    required this.onWebsite,
  });

  final ProfessionalService professional;
  final Future<void> Function() onBook;
  final Future<void> Function() onCall;
  final Future<void> Function() onEmail;
  final Future<void> Function() onDirections;
  final Future<void> Function() onWebsite;

  @override
  Widget build(BuildContext context) {
    final imageUri = Uri.tryParse(professional.imageUrl ?? '');
    final validImage = imageUri != null &&
        (imageUri.isScheme('http') || imageUri.isScheme('https')) &&
        imageUri.host.isNotEmpty;
    final hasEmail = (professional.email ?? '').trim().isNotEmpty;
    final hasWebsite = (professional.website ?? '').trim().isNotEmpty;
    final hasAddress = (professional.address ?? '').trim().isNotEmpty;
    final rateLabel = professional.verifiedSource == 'google_places'
        ? '${professional.formattedRate} est.'
        : professional.formattedRate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipOval(
                    child: validImage
                        ? Image.network(
                            professional.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _InitialAvatar(initials: professional.initials),
                          )
                        : _InitialAvatar(initials: professional.initials),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        professional.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < professional.rating.floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                          const SizedBox(width: 4),
                          Text(
                            professional.ratingDisplay,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rateLabel,
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              professional.specialty,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              professional.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            if (hasAddress || professional.distanceDisplay.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (professional.distanceDisplay.isNotEmpty)
                          professional.distanceDisplay,
                        if (hasAddress) professional.address!.trim(),
                      ].join(' | '),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (professional.serviceAreas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: professional.serviceAreas.map((area) {
                  return Chip(
                    label: Text(area),
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.book_online, size: 18),
                label: Text(I18nService.translate("Book Service")),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(I18nService.translate("Call")),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasEmail ? onEmail : onDirections,
                    icon: Icon(
                      hasEmail ? Icons.email : Icons.directions,
                      size: 18,
                    ),
                    label: Text(
                      hasEmail
                          ? I18nService.translate("Email")
                          : I18nService.translate("Directions"),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (hasWebsite) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onWebsite,
                  icon: const Icon(Icons.language, size: 18),
                  label: Text(I18nService.translate("Visit Website")),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.green.shade100,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.green.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _ProfessionalResultsCacheEntry {
  const _ProfessionalResultsCacheEntry({
    required this.savedAtMs,
    required this.services,
    required this.meta,
  });

  final int savedAtMs;
  final List<ProfessionalService> services;
  final NearbyProfessionalsMeta? meta;

  Map<String, dynamic> toJson() => {
        'savedAtMs': savedAtMs,
        'services': services.map((entry) => entry.toJson()).toList(),
        'meta': meta?.toJson(),
      };

  static _ProfessionalResultsCacheEntry? fromJson(Map<String, dynamic> json) {
    final savedAtMs = (json['savedAtMs'] as num?)?.toInt();
    final servicesRaw = json['services'];
    if (savedAtMs == null || servicesRaw is! List<dynamic>) {
      return null;
    }
    final services = servicesRaw
        .whereType<Map<String, dynamic>>()
        .map(ProfessionalService.fromJson)
        .toList(growable: false);
    final metaRaw = json['meta'];
    final meta = metaRaw is Map<String, dynamic>
        ? NearbyProfessionalsMeta.fromJson(metaRaw)
        : null;
    return _ProfessionalResultsCacheEntry(
      savedAtMs: savedAtMs,
      services: services,
      meta: meta,
    );
  }
}

class _ResolvedLookupLocation {
  const _ResolvedLookupLocation._({
    this.latitude,
    this.longitude,
    this.locationQuery,
  });

  factory _ResolvedLookupLocation.gps({
    required double latitude,
    required double longitude,
  }) =>
      _ResolvedLookupLocation._(
        latitude: latitude,
        longitude: longitude,
      );

  factory _ResolvedLookupLocation.manual(String locationQuery) =>
      _ResolvedLookupLocation._(locationQuery: locationQuery);

  final double? latitude;
  final double? longitude;
  final String? locationQuery;
}
