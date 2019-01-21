#
# Be sure to run `pod lib lint SHLogger.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SHLogger'
  s.version          = '1.7.0'
  s.summary          = 'It is a module to collect logs.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  这是一个日志收集模块，使用者可以通过配置指定实时上传日志，或是通过指令上传日志， 也可以通过Airdrop分享日志到Mac或是其它支持
  Airdrop的苹果设备.
                       DESC

  s.homepage         = 'http://evergrande.cn/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'maoyifeng' => 'maoyifeng@evergrande.cn' }
  s.source           = { :git => 'ssh://git@gitlab.egtest.cn:10022/ios/SHLogger.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'SHLogger/Classes/**/*.{h,m,mm,cc}'
  
  # s.resource_bundles = {
  #   'SHLogger' => ['SHLogger/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/*"'}
  s.dependency 'Reachability', '~>3.2'
  s.dependency 'AFNetworking', '~>3.2'
  s.dependency 'SSZipArchive', '~>2.1'

end
