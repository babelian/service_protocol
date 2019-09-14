guard :bundler do
  watch('Gemfile')
  # watch(/^.+\.gemspec/)
end

guard :rspec, cmd: '_=guard bundle exec rspec -f doc' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb') { 'spec' }
  watch(%r{^spec/support/(.+)\.rb$}) { 'spec' }
end
