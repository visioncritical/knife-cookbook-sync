#!/usr/bin/env ruby

module Knife
  class CookbookSync < Chef::Knife

    deps do
      require 'chef/knife/cookbook_metadata'
      require 'chef/rest'

      begin
        require 'chef/checksum_cache'
      rescue LoadError
      end

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
      :description => "The path that cookbooks should be loaded from (path:path)",
      :proc        => proc { |x| x.split(":") }

    option :quiet,
      :short        => '-q',
      :long         => '--quiet',
      :description  => "Make less noise",
      :default      => false

    def make_noise(&block)
      force_make_noise(&block) if block and !config[:quiet]
    end

    def force_make_noise(&block)
      @print_mutex.synchronize(&block) if block
    end

    def distill_manifest(cookbook)
      files = { }
      cookbook.manifest.values.select { |x| x.kind_of?(Array) }.flatten.each { |f| files[f['path']] = f['checksum'] }
      # don't check metadata.json since json output is indeterministic, metadata.rb should be all that's needed anw
      files.delete('metadata.json')
      return files
    end

    def sync_cookbooks(cookbooks, cl)
      log_level = Chef::Log.level

      # mutes the CookbookVersion noise when the cookbook doesn't exist on the server.
      Chef::Log.level = :fatal

      to_upload = Queue.new

      cookbooks.map(&:to_s).map do |cookbook|
        Thread.new do
          upload = false

          make_noise do
            ui.msg "Checking cookbook '#{cookbook}' for sync necessity"
          end

          remote_cookbook = Chef::CookbookVersion.available_versions(cookbook) &&
            (Chef::CookbookVersion.load(cookbook.to_s) rescue nil)
          local_cookbook = cl[cookbook.to_s] rescue nil

          unless local_cookbook
            make_noise do
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
            make_noise do
              ui.msg "sync necessary; uploading '#{cookbook}'"
            end

            to_upload << cl[cookbook]
          end
        end
      end.each(&:join)

      cookbooks_to_upload = []
      loop { cookbooks_to_upload << to_upload.shift(true) } rescue nil

      # exit 0 if there's nothing to upload
      if cookbooks_to_upload.empty?
        exit 0
      end

      Chef::Log.level = log_level # restore log level now that we're done checking
      Chef::CookbookUploader.new(cookbooks_to_upload, Chef::Config[:cookbook_path]).upload_cookbooks

      # exit with an exit status of 5 if we've uploaded anything.
      exit 5
    end

    def run
      Thread.abort_on_exception = true

      @print_mutex = Mutex.new

      Chef::Config[:cookbook_path] = config[:cookbook_path] if config[:cookbook_path]

      Chef::Cookbook::FileVendor.on_create { |manifest| Chef::Cookbook::FileSystemFileVendor.new(manifest) }

      cl = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])
      cl.load_cookbooks if cl.respond_to?(:load_cookbooks)

      if config[:all]
        if cl.respond_to?(:cookbook_names)
          names = cl.cookbook_names
        else
          names = cl.cookbooks.map(&:name)
        end

        sync_cookbooks names, cl
      else
        sync_cookbooks name_args, cl
      end
    end
  end
end
