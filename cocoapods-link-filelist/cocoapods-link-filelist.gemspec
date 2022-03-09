
Gem::Specification.new do |spec|
  spec.name = "cocoapods-link-filelist"
  spec.version = '1.0.1'
  spec.authors = ["shyang"]
  spec.email = ["shaohua0110@yahoo.com"]

  spec.summary = "A filelist substitution plugin for cocoapods."
  spec.description = "This plugin modifies LD_FLAGS in Pods/Target Support Files/*/*.xcconfig
  replacing multiple -l flags with a single filelist to speed up linking."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"
  spec.files = ["lib/cocoapods_plugin.rb", "lib/link_filelist_optimize.rb"]
  spec.homepage = 'https://github.com/shyang/cocoapods-link-filelist'

end
