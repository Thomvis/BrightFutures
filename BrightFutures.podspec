Pod::Spec.new do |s|
  s.name = 'BrightFutures'
  s.version = '3.1.1'
  s.license = 'MIT'
  s.summary = 'Write great asynchronous code in Swift using futures and promises'
  s.homepage = 'https://github.com/Thomvis/BrightFutures'
  s.social_media_url = 'https://twitter.com/thomvis88'
  s.authors = { 'Thomas Visser' => 'thomas.visser@gmail.com' }
  s.source = { :git => 'https://github.com/Thomvis/BrightFutures.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'

  s.source_files = 'BrightFutures/*.swift'

  s.dependency 'Result', '0.6.0-beta.6'

  s.requires_arc = true
end
