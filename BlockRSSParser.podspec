Pod::Spec.new do |s|
  s.name         = "BlockRSSParser"
  s.version      = "2.1"
  s.summary      = "AFNetworkingXMLRequestOperation based RSS parser."
  s.homepage     = "https://github.com/MichiganLabs/BlockRSSParser"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Thibaut LE LEVIER" => "thibaut@lelevier.fr" }

  s.source       = { :git => "https://github.com/MichiganLabs/BlockRSSParser.git", :branch => "master" }

  s.requires_arc = true

  s.platform     = :ios
  s.ios.deployment_target = '6.0'

  s.source_files = 'Classes', 'RSSParser/*.{h,m}'
end
