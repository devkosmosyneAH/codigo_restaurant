import 'package:flutter/widgets.dart';

import 'local_image_provider_stub.dart'
    if (dart.library.io) 'local_image_provider_io.dart'
    as impl;

ImageProvider<Object>? buildLocalImageProvider(String path) {
  return impl.buildLocalImageProvider(path);
}
