platform :ios, '15.0'

target 'ICO-visualizer' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ICO-visualizer
  pod 'Alamofire'
  pod 'SDWebImage'
  pod 'ImageViewer.swift', '~> 3.0'
  pod 'ImageViewer.swift/Fetcher', '~> 3.0'
  pod 'CCBottomRefreshControl'
  pod 'SVPinView', '~> 1.0'
  pod 'AlamofireNetworkActivityLogger'
end

# Old pods declare very low deployment targets that modern Xcode no longer supports.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end
