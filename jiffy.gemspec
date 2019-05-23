# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__), 'lib', 'jiffy', 'version.rb'])
# rubocop:disable Lint/UselessAssignment
spec = Gem::Specification.new do |s|
  s.name = 'jiffy'
  s.version = Jiffy::VERSION
  s.author = 'Peyton Walters'
  s.email = 'pwpon500@gmail.com'
  # s.homepage = 'http://your.website.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'A command-line app to do automated virtual machine deployment'
  s.files = `git ls-files`.split('
')
  s.require_paths << 'lib'
  s.bindir = 'bin'
  s.executables << 'jiffy'
  s.add_development_dependency('rspec')
  s.add_development_dependency('rubocop')
  s.add_runtime_dependency('gli', '2.17.0')
  s.add_runtime_dependency('json')
  s.add_runtime_dependency('ruby-libvirt')
end
# rubocop:enable Lint/UselessAssignment
