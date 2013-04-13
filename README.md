# knife cookbook sync

*Note*: this gem has been renamed to be more conformant with knife plugin
naming on rubygems.org. The original gem was named
[knife_cookbook_sync](https://rubygems.org/gems/knife_cookbook_sync).

Sync your cookbooks faster than `knife cookbook upload` or alternatives.

`knife cookbook sync` is primarily a development tool, but can be used for
production work with careful coordination with an external cookbook resolver.

Here's the meat. `knife cookbook sync` vs `knife cookbook upload` with a
pre-uploaded corpus of 39 cookbooks, using the standard unix `time` utility to
benchmark on MRI 1.9.3-p327 and chef 10.16.2:

* `knife cookbook sync -a`: 1.31s user 0.15s system 72% cpu **2.020 total**
* `knife cookbook upload -a`: 1.34s user 0.15s system 15% cpu **9.684 total**

Instead of resolving and uploading everything (or even what you ask to upload),
it uses the cryptographic sums chef already generates to determine what needs
to be uploaded, and only uploads what's different.

This means it **does not check versions and dependencies**. It cheats, so you
should be sure you have your ducks in a row before uploading by using a
cookbook resolver. This only matters for determining what to upload -- cookbooks
uploaded with `knife cookbook sync` are no different otherwise (and in fact use
chef's own cookbook uploading tooling to do it).

Unsurprisingly, the more that has changed, the more the performance will
decrease slowly towards `knife cookbook upload` performance. The gains are
really only seen when you need to sync whole repositories where most or all of
the product that's on-disk has already been uploaded. It's particularly nice
for fast test cycles where you just don't want to care just yet what cookbooks
have changed. However, you can use it for all uploading without any real issue.

`knife cookbook sync` has no dependencies other than chef, and is compatible
with both chef 10.x and 11.x. 

## Installation

Add this line to your application's Gemfile:

    gem 'knife-cookbook-sync'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install knife-cookbook-sync

## Usage

`knife cookbook sync` takes a list of cookbooks or `-a` to upload everything.
It uses your `cookbook_path` `knife.rb` settings to determine what's available
to upload which is overridable by `-o`.

If you pass `-d`, it'll perform a "dry run" and just show you what it would
upload.

See "Exit Statuses" below for information on how `knife cookbook sync` can let
you know what it did (you know, for scripting yo).

For more information, use `knife cookbook sync --help`.

## Exit Statuses

The following exit codes are used in various situations:

* 0: nothing went wrong, but we did not see anything different. Works in dry run and sync mode.
* 1: Something is not right -- usually this means you have a broken
  `cookbook_path` or did not supply `-o`. Whereever Chef is sending its UI
  output will have the information you seek (usually Standard Error).
* 5: nothing went wrong, but there are differences between what's in your
  `cookbook_path` and the chef server. Works in dry run and sync mode.

## Chef-Workflow support

We support [chef-workflow](https://github.com/chef-workflow/chef-workflow) by
way of a task you can use.

Add the 'knife-cookbook-sync' gem to your `Gemfile` (version `0.1.0` or later),
and this to your `Rakefile`:

```ruby
chef_workflow_task 'chef/cookbooks/sync'
```

And you'll have a `chef:cookbooks:sync` rake target you can use.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Authors

* Erik Hollensbe <erik+github@hollensbe.org>
