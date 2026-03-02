class ProductLinkService {
  static Uri? parseHttpUri(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;
    if (!(uri.isScheme('https') || uri.isScheme('http'))) return null;
    if (uri.host.trim().isEmpty) return null;
    return uri;
  }

  static String deriveMerchantLabel(String rawUrl) {
    final uri = parseHttpUri(rawUrl);
    if (uri == null) return 'Web';

    final host = uri.host.toLowerCase();
    if (host.contains('amazon.')) return 'Amazon';
    if (host.contains('target.')) return 'Target';
    if (host.contains('walmart.')) return 'Walmart';
    if (host.contains('bestbuy.')) return 'Best Buy';
    if (host.contains('ebay.')) return 'eBay';
    if (host.contains('ikea.')) return 'IKEA';
    if (host.contains('homedepot.')) return 'Home Depot';
    if (host.contains('wayfair.')) return 'Wayfair';

    final parts = host.split('.');
    if (parts.isEmpty) return 'Web';
    final root = parts.first;
    if (root.isEmpty) return 'Web';
    return root[0].toUpperCase() + root.substring(1);
  }
}
