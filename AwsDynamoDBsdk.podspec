Pod::Spec.new do |s|

  s.name         = "AwsDynamoDBsdk"
  s.version      = "0.2.0"
  s.summary      = "Swift library providing easy access to common DynamoDB operations"
  s.homepage     = "https://github.com/nikola-mladenovic/AwsSwiftDynamoDBsdk"
  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.author       = { "Nikola Mladenovic" => "nikola@mladenovic.biz" }
  s.source       = { :git => "https://github.com/nikola-mladenovic/AwsSwiftDynamoDBsdk.git", :tag => s.version.to_s }
  s.source_files = 'Sources/AwsDynamoDB/*.swift'
  s.swift_version = "4.2"
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.2' }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.2'

  s.dependency 'AwsSign', '~> 0.2'

end
