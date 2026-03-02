import 'package:clutterzen/services/product_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductLinkService.deriveMerchantLabel', () {
    test('derives known merchants from URL host', () {
      expect(
        ProductLinkService.deriveMerchantLabel(
            'https://www.amazon.com/s?k=storage+baskets'),
        'Amazon',
      );
      expect(
        ProductLinkService.deriveMerchantLabel(
            'https://www.target.com/s?searchTerm=closet+baskets'),
        'Target',
      );
      expect(
        ProductLinkService.deriveMerchantLabel(
            'https://www.walmart.com/search?q=file+organizer'),
        'Walmart',
      );
    });

    test('falls back for invalid or unknown domains', () {
      expect(ProductLinkService.deriveMerchantLabel('not-a-url'), 'Web');
      expect(
        ProductLinkService.deriveMerchantLabel(
            'https://myshop.example/items/1'),
        'Myshop',
      );
    });
  });

  group('ProductLinkService.parseHttpUri', () {
    test('accepts only valid http/https links', () {
      expect(
        ProductLinkService.parseHttpUri(
            'https://www.amazon.com/s?k=drawer+dividers'),
        isNotNull,
      );
      expect(
        ProductLinkService.parseHttpUri('http://example.com/item'),
        isNotNull,
      );
      expect(ProductLinkService.parseHttpUri('ftp://example.com'), isNull);
      expect(ProductLinkService.parseHttpUri(''), isNull);
    });
  });
}
