require 'knife/dsl'
require 'chef-workflow/tasks/bootstrap/knife'

namespace :chef do
  namespace :cookbooks do
    desc "Upload your cookbooks to the chef server"
    task :sync => [ "bootstrap:knife" ] do
      Rake::Task["chef:cookbooks:resolve"].invoke rescue nil
      result = knife %W[cookbook sync -a]
      fail if result != 0
    end
  end
end
