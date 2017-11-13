#
# Be sure to run `pod lib lint incremental-simplified.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'incremental-simplified'
  s.version          = '0.1.0'
  s.summary          = 'This is an implementation of incremental programming.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This is an implementation of incremental programming. It's based on the ideas in [incremental](https://blog.janestreet.com/introducing-incremental/), which are on turn based on the ideas of [self-adjusting computation](http://www.umut-acar.org/self-adjusting-computation).
                       DESC

  s.homepage         = 'https://github.com/agustindc-rga/incremental-simplified'
  s.license          = { :type => 'Custom', :file => 'LICENSE' }
  s.author           = { 'Chris Eidhof' => 'chris@eidhof.nl' }
  s.source           = { :git => 'https://github.com/agustindc-rga/incremental-simplified.git' }

  s.ios.deployment_target = '10.0'

  s.source_files = 'Incremental/**/*.swift'
  
end
