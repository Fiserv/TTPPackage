Pod::Spec.new do |s|

  s.name = 'FiservTTP'
  s.version = '1.0.5'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'Tap To Pay on iPhone by Fiserv'
  s.homepage = 'https://github.com/Fiserv/TTPPackage'
  s.authors = { 'Fiserv' => 'richard.tilt@fiserv.com' }
  s.source = { :git => 'https://github.com/Fiserv/TTPPackage.git', :tag => s.version }
  s.documentation_url = 'https://github.com/Fiserv/TTPPackage'

  s.ios.deployment_target = '16.7'

  s.swift_versions = ['5']

  s.source_files = 'Sources/FiservTTP/*.swift'
  
end
