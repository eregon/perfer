Gem::Specification.new do |s|
  s.name = 'perfer'
  s.summary = 'A benchmark tool for all rubies!'
  s.author = 'eregon'
  s.email = 'eregontp@gmail.com'
  s.homepage = 'https://github.com/jruby/perfer'
  s.files = Dir['bin/*'] + Dir['lib/**/*.rb'] + %w[README.md LICENSE perfer.gemspec]
  s.executables << 'perfer'
  s.add_dependency 'path', '~> 1.3.1'
  s.add_dependency 'hitimes', '~> 1.1.1'
  s.version = '0.2.1'
end
