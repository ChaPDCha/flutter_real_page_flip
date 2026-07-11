#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint real_page_flip.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'real_page_flip'
  s.version          = '1.16.1'
  s.summary          = 'A high-fidelity 3D-like page flip engine for Flutter.'
  s.description      = <<-DESC
A high-fidelity 3D-like page flip engine for Flutter. Features physics-based paper fold effects with realistic shadows, sound, and haptic feedback.
                       DESC
  s.homepage         = 'https://github.com/ChaPDCha/flutter_real_page_flip'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ChaPDCha' => 'https://github.com/ChaPDCha' }
  s.source           = { :path => '.' }
  s.source_files = 'real_page_flip/Sources/real_page_flip/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'real_page_flip_privacy' => ['real_page_flip/Sources/real_page_flip/PrivacyInfo.xcprivacy']}
end
