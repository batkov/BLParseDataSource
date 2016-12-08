#
# Be sure to run `pod lib lint BLParseFetch.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "BLParseFetch"
  s.version          = "0.3.1"
  s.summary          = "BLParseFetch is implementation of BLFetch(as part of BLListDataSource) for Parse Platform"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
  Implementation of BLFetch object for Parse platform. Can be used with BLListViewController.
                       DESC

  s.homepage         = "https://github.com/batkov/BLParseFetch"
  s.license          = 'MIT'
  s.author           = { "Hariton Batkov" => "batkov@i.ua" }
  s.source           = { :git => "https://github.com/batkov/BLParseFetch.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
 s.dependency 'Parse'
 s.dependency 'BLListDataSource'
end
