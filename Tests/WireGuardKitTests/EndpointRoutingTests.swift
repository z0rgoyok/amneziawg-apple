import Network
import NetworkExtension
import XCTest
@testable import WireGuardKit

#if os(macOS)
final class EndpointRoutingTests: XCTestCase {
    func testIPv4ServiceAtPeerEndpointStaysInsideSplitTunnel() throws {
        let settings = try makeSettings(endpoint: "192.0.2.10:51820", allowed: "192.0.2.10/32")
        XCTAssertTrue(settings.ipv4Settings!.includedRoutes!.contains {
            $0.destinationAddress == "192.0.2.10" && $0.destinationSubnetMask == "255.255.255.255"
        })
        XCTAssertFalse(settings.ipv4Settings!.includedRoutes!.contains { $0.destinationAddress == "0.0.0.0" })
        XCTAssertTrue(settings.ipv4Settings!.excludedRoutes!.isEmpty)
        XCTAssertNil(settings.dnsSettings)
    }

    func testIPv6ServiceAtPeerEndpointStaysInsideSplitTunnel() throws {
        let settings = try makeSettings(endpoint: "[2001:db8::10]:51820", allowed: "2001:db8::10/128")
        XCTAssertTrue(settings.ipv6Settings!.includedRoutes!.contains {
            $0.destinationAddress == "2001:db8::10" && $0.destinationNetworkPrefixLength == 128
        })
        XCTAssertTrue(settings.ipv6Settings!.excludedRoutes!.isEmpty)
    }

    func testExplicitEndpointExclusionIsPreserved() throws {
        let settings = try makeSettings(
            endpoint: "192.0.2.10:51820",
            allowed: "192.0.2.10/32",
            excluded: ["192.0.2.10/32", "2001:db8::20/128"]
        )
        XCTAssertEqual(settings.ipv4Settings!.excludedRoutes!.map(\.destinationAddress), ["192.0.2.10"])
        XCTAssertEqual(settings.ipv6Settings!.excludedRoutes!.map(\.destinationAddress), ["2001:db8::20"])
    }

    private func makeSettings(endpoint: String, allowed: String, excluded: [String] = []) throws -> NEPacketTunnelNetworkSettings {
        var interface = InterfaceConfiguration(privateKey: PrivateKey())
        interface.addresses = [try XCTUnwrap(IPAddressRange(from: "10.0.0.2/32"))]
        var peer = PeerConfiguration(publicKey: PrivateKey().publicKey)
        peer.endpoint = try XCTUnwrap(Endpoint(from: endpoint))
        peer.allowedIPs = [try XCTUnwrap(IPAddressRange(from: allowed))]
        peer.excludeIPs = try excluded.map { try XCTUnwrap(IPAddressRange(from: $0)) }
        let tunnel = TunnelConfiguration(name: "routing-test", interface: interface, peers: [peer])
        return PacketTunnelSettingsGenerator(tunnelConfiguration: tunnel, resolvedEndpoints: [peer.endpoint])
            .generateNetworkSettings()
    }
}
#endif
