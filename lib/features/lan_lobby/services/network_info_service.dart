import 'dart:io';

/// Resolves this device's own LAN-reachable IPv4 addresses.
///
/// Native app clients find the host via mDNS, which a browser cannot do on
/// its own, so the host needs to show joiners an explicit `http://ip:port`
/// URL (and a QR code for it) instead.
class NetworkInfoService {
  const NetworkInfoService();

  Future<List<String>> localIPv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.isLoopback) continue;
        addresses.add(addr.address);
      }
    }
    return addresses;
  }
}
