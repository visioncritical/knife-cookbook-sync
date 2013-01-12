#!/usr/bin/env ruby

module Knife
  class CookbookSync < Chef::Knife

    deps do
      require 'chef/knife/cookbook_metadata'
      require 'chef/rest'
      require 'chef/checksum_cache'
      require 'chef/cookbook_loader'
      require 'chef/cookbook_uploader'
      require 'chef/cookbook_version'
      require 'chef/log'
    end

    banner "knife cookbook sync [COOKBOOKS...]"

    option :dry_run,
      :short       => '-d',
      :long        => '--dry-run',
      :boolean     => true,
      :description => "Do a dry run -- do not sync anything, just show what would be synced"

    option :all,
      :short       => '-a',
      :long        => '--all',
      :boolean     => true,
      :description => "Sync all cookbooks"

    option :cookbook_path,
      :short       => '-o [COOKBOOK PATH]',
      :long        => '--cookbook-path [COOKBOOK PATH]',
      :default     => %w[cookbooks site-cookbooks],
      :description => "The path that cookbooks should be loaded from (path:path)",
      :proc        => proc { |x| x.split(":") }


    def distill_manifest(cookbook)
      files = { }
      cookbook.manifest.values.select { |x| x.kind_of?(Array) }.flatten.each { |f| files[f['path']] = f['checksum'] }
      # don't check metadata.json since json output is indeterministic, metadata.rb should be all that's needed anw
      files.delete('metadata.json')
      return files
    end

    def sync_cookbooks(cookbooks, cl)
      uploaded = false
      log_level = Chef::Log.level

      # mutes the CookbookVersion noise when the cookbook doesn't exist on the server.
      Chef::Log.level = :fatal

      print_mutex = Mutex.new

      cookbooks.each do |cookbook|
        Thread.new do
          upload = false
          print_mutex.synchronize do
            ui.msg "Checking cookbook '#{cookbook}' for sync necessity"
          end

          remote_cookbook = Chef::CookbookVersion.load(cookbook.to_s)
          local_cookbook = cl[cookbook.to_s] rescue nil

          unless local_cookbook
            print_mutex.synchronize do
              ui.fatal "Cookbook '#{cookbook}' does not exist locally."
            end
            exit 1
          end

          if local_cookbook and !remote_cookbook
            upload = true
          else
            remote_files = distill_manifest(remote_cookbook) rescue { }
            local_files  = distill_manifest(local_cookbook) rescue { }

            if local_files.keys.length != remote_files.keys.length
              upload = true
            else
              (local_files.keys + remote_files.keys).uniq.each do |filename|
                if local_files[filename] != remote_files[filename]
                  upload = true
                  break
                end
              end
            end
          end

          if upload
            print_mutex.synchronize do
              ui.msg "sync necessary; uploading '#{cookbook}'"
            end

            retries_left = 5

            begin
              #
              # XXX
              #
              # For some godawful reason, if we use the local_cookbook referenced
              # above, the MD5 sums are off.
              #
              # So we reload the cookbooks here because it seems to work, with an
              # optional retry if the chef server is being pissy.
              #
              cl = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])

              if config[:dry_run]
                print_mutex.synchronize do
                  ui.warn "dry run: would sync '#{cookbook}'"
                end
              else
                Chef::CookbookUploader.new(cl[cookbook], Chef::Config[:cookbook_path]).upload_cookbooks
              end

              uploaded = true
            rescue Exception => e
              print_mutex.synchronize do
                ui.error "Failed to upload; retrying up to #{retries_left} times"
              end

              retries_left -= 1
              if retries_left > 0
                retry
              else
                raise e
              end
            end
          end
        end
      end

      Thread.list.reject { |x| x == Thread.current }.each(&:join)
      Chef::Log.level = log_level # restore log level now that we're done checking

      # exit with an exit status of 5 if we've uploaded anything.
      exit uploaded ? 5 : 0
    end

    def run
      Chef::Config[:cookbook_path] = config[:cookbook_path]
      Thread.abort_on_exception = true

      Chef::Cookbook::FileVendor.on_create { |manifest| Chef::Cookbook::FileSystemFileVendor.new(manifest) }

      cl = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])

      if config[:all]
        sync_cookbooks cl.cookbooks.map(&:name), cl
      else
        sync_cookbooks name_args, cl
      end
    end
  end
end
