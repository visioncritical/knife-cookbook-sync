require 'knife/dsl'
require 'chef-workflow/tasks/bootstrap/knife'

namespace :chef do
  namespace :cookbooks do
    desc "Upload your cookbooks to the chef server"
    task :sync => [ "bootstrap:knife" ] do
      resolve_task = Rake::Task["chef:cookbooks:resolve"] rescue nil
      resolve_task.invoke if resolve_task

      result = knife %W[cookbook sync -a]
      fail unless [0, 5].include?(result)
    end
  end
end
