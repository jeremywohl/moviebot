require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/test_*.rb']
  t.verbose = true
  t.warning = true
end

task default: :test
