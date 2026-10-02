# LAIka App

LAIka App is a phone app for LAIka, the self-hosted AI software-engineering control plane.

License: GPL-3.0

Build Android with `flutter build apk`.

Build iOS with `flutter build ios` (needs a Mac with Xcode).

## iOS VPN setup (needs a paid Apple developer account)

In Xcode, add the App Groups and Network Extensions capabilities to the Runner's target. Click the `+` button on the bottom left, choose **NETWORK EXTENSION**, and create a Network Extension target named `VPNExtension`.

Add the same App Groups and Network Extensions capabilities to `VPNExtension`. Configure the app bundle identifier as `dev.laika.app`, the extension bundle identifier as `dev.laika.app.VPNExtension`, and the App Group as `group.dev.laika.app` for both targets.

Add this target to `ios/Podfile`:

```ruby
target 'VPNExtension' do
  use_frameworks!
  pod 'OpenVPNAdapter', :git => 'https://github.com/ss-abramchuk/OpenVPNAdapter.git', :tag => '0.8.0'
end
```

Open `VPNExtension > PacketTunnelProvider.swift` and copy the script from [openvpn_flutter's PacketTunnelProvider.swift](https://raw.githubusercontent.com/nizwar/openvpn_flutter/master/example/ios/VPNExtension/PacketTunnelProvider.swift).
