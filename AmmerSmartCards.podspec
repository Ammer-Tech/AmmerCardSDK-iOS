Pod::Spec.new do |s|
s.name             = 'AmmerSmartCards'
s.version          = '1.6.2'
s.summary          = 'The Ammer Smart Cards for iOS'
s.description      = 'Ammer Smart Cards. Use it to activate and get public key from phisical card.'
s.homepage         = 'https://github.com/Ammer-Tech/AmmerSmartCards'
s.license          = 'MIT'
s.author           = { 'Ammer Tech' => 'info@ammer.tech' }
s.source           = { :git => 'https://github.com/Ammer-Tech/AmmerSmartCards.git', :tag => s.version.to_s }
s.ios.deployment_target = '14.0'
s.source_files = 'Sources/*.*'
end
