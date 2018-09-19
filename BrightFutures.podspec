Pod::Spec.new do |s|
  s.name = 'BrightFutures'
  s.version = '7.0.0'
  s.license = 'MIT'
  s.summary = 'Write great asynchronous code in Swift using futures and promises'
  s.homepage = 'https://github.com/Thomvis/BrightFutures'
  s.social_media_url = 'https://twitter.com/thomvis'
  s.authors = { 'Thomas Visser' => 'thomas.visser@gmail.com' }
  s.source = { :git => 'https://github.com/Thomvis/BrightFutures.git', :tag => "#{s.version}" }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'Sources/BrightFutures/*.swift'

  s.dependency 'Result', '~> 4.0.0'

  s.requires_arc = true

  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.2' }
end
