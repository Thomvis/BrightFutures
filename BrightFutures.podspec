Pod::Spec.new do |s|
  s.name = 'BrightFutures'
  s.version = '2.0.0-beta.1'
  s.license = 'MIT'
  s.summary = 'A simple Futures & Promises library for iOS and OS X written in Swift'
  s.homepage = 'https://github.com/Thomvis/BrightFutures'
  s.social_media_url = 'https://twitter.com/thomvis88'
  s.authors = { 'Thomas Visser' => 'thomas.visser@gmail.com' }
  s.source = { :git => 'https://github.com/Thomvis/BrightFutures.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'BrightFutures/*.swift'

  s.dependency 'Result', '~> 0.4.2'

  s.requires_arc = true
end