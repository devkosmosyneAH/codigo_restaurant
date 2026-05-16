/// Construye URLs públicas para rutas que se comparten por QR.
class PublicRouteUrlBuilder {
  PublicRouteUrlBuilder._();

  static String route(
    String route, {
    required String fallbackUrl,
    Map<String, String>? queryParameters,
    Uri? currentUri,
  }) {
    final current = currentUri ?? Uri.base;
    final fragment = _routeFragment(route, queryParameters);

    if (_isHttpUrl(current)) {
      final baseUri = Uri(
        scheme: current.scheme,
        userInfo: current.userInfo,
        host: current.host,
        port: current.hasPort ? current.port : null,
        path: current.path,
        fragment: fragment,
      );
      return baseUri.toString();
    }

    final fallback = Uri.parse(fallbackUrl);
    if (queryParameters == null || queryParameters.isEmpty) {
      return fallback.toString();
    }

    return fallback
        .replace(
          queryParameters: {...fallback.queryParameters, ...queryParameters},
        )
        .toString();
  }

  static bool _isHttpUrl(Uri uri) {
    return uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static String _routeFragment(
    String route,
    Map<String, String>? queryParameters,
  ) {
    final normalizedRoute = route.startsWith('/') ? route : '/$route';
    if (queryParameters == null || queryParameters.isEmpty) {
      return normalizedRoute;
    }

    return '$normalizedRoute?${Uri(queryParameters: queryParameters).query}';
  }
}
