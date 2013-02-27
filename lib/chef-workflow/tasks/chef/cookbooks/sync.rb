require 'knife/dsl'
require 'chef-workflow/tasks/bootstrap/knife'

namespace :chef do
  namespace :cookbooks do
    desc "Upload your cookbooks to the chef server"
    task :sync => [ "bootstrap:knife" ] do
      Rake::Task["chef:cookbooks:resolve"].invoke rescue nil
      result = knife %W[cookbook sync -a]
      fail unless [0, 5].include?(result)
    end
  end
end
