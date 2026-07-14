Pod::Spec.new do |s|
  s.name             = "TheQuestOfferwall"
  s.version          = "0.2.0" # x-release-please-version
  s.summary          = "Embed The Quest offerwall in your iOS app with a single show() call."
  s.description      = <<-DESC
    The Quest Offerwall SDK hosts the Quest offerwall in a WKWebView with a native header.
    Configure your app id in Info.plist and call TheQuest.shared.show(from:userId:) —
    standard (unsigned) and secure (server-signed launch) modes are both supported.
  DESC
  s.homepage         = "https://github.com/humanlabs-kr/the-quest-sdk"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.authors          = { "Humanlabs" => "engineering@humanlabs.world" }

  s.source           = { :git => "https://github.com/humanlabs-kr/the-quest-sdk.git", :tag => "ios-v#{s.version}" }

  s.platform         = :ios, "15.0"
  s.ios.deployment_target = "15.0"
  s.swift_version    = "5.9"

  s.source_files     = "ios/Sources/TheQuestOfferwall/**/*.swift"
  s.resource_bundles = { "TheQuestOfferwall" => ["ios/Sources/TheQuestOfferwall/Resources/PrivacyInfo.xcprivacy"] }

  s.frameworks       = "UIKit", "WebKit"
end
