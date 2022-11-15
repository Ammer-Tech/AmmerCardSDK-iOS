Pod::Spec.new do |s|
s.name             = 'AmmerPaymentsSDK'
s.version          = '1.6.2'
s.summary          = 'The Ammer Payments SDK for iOS'
s.description      = 'The Ammer Payments SDK enables your iOS application to use a paments in Ammer Platform'
s.homepage         = 'https://github.com/Ammer-Tech/AmmerPaymentsSDK'
s.license          = 'MIT'
s.author           = { 'Ammer Tech' => 'info@ammer.tech' }
s.source           = { :git => 'https://github.com/Ammer-Tech/AmmerPaymentsSDK.git', :tag => s.version.to_s }
s.ios.deployment_target = '14.0'
s.source_files = 'Sources/*.*'
end
