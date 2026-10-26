#
# CocoaPods spec for apps that build without Swift Package Manager.
#
Pod::Spec.new do |s|
  s.name             = 'stratum_ui'
  s.version          = '0.0.1'
  s.summary          = 'The iOS and macOS sender channel of StratumWebView.'
  s.description      = <<-DESC
Carries StratumWebView page messages with the sender frame WebKit names.
                       DESC
  s.homepage         = 'https://github.com/nontravis/stratum_flutter_ui'
  s.author           = { 'Nonthawit Doungsodsri' => 'nonthawit.kub@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'stratum_ui/Sources/stratum_ui/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
