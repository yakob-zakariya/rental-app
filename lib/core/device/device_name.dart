import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The API accepts a `deviceName` of at most 100 characters.
const maxDeviceNameLength = 100;

/// A readable phone name for `POST /auth/otp/verify`, e.g. `samsung` +
/// `SM-M156B` → "Samsung SM-M156B". Skips the maker when the model already
/// starts with it ("Xiaomi 13"). `null` when nothing is known.
String? formatDeviceName(String manufacturer, String model) {
  final maker = manufacturer.trim();
  final name = model.trim();

  final String result;
  if (name.isEmpty) {
    result = _capitalize(maker);
  } else if (maker.isEmpty ||
      name.toLowerCase().startsWith(maker.toLowerCase())) {
    result = name;
  } else {
    result = '${_capitalize(maker)} $name';
  }

  if (result.isEmpty) return null;
  return result.length > maxDeviceNameLength
      ? result.substring(0, maxDeviceNameLength)
      : result;
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// This phone's name, read once. `null` if it can't be read (it's optional
/// in the API contract). A `FutureProvider` is a provider whose value arrives
/// asynchronously; `ref.read(deviceNameProvider.future)` awaits it.
final deviceNameProvider = FutureProvider<String?>((ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return formatDeviceName(info.manufacturer, info.model);
  } on Exception {
    return null;
  }
});
