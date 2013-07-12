require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => [:spec] # [:spec, :benchmarks]

desc 'Run all testperf scripts'
task :benchmarks do
  Dir['testperf/*'].each do |fn|
    system "bundle exec ruby #{fn}"
  end
end