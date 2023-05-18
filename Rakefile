require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "src/tests"
  t.test_files = FileList['src/tests/test_*.rb']
  t.verbose = true
  t.warning = true
end

task default: :test
