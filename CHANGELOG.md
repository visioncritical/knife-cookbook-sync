0.2.1 (07/27/2014)
==================

* Added :pipeline routine for low output

0.2.0 (07/25/2014)
==================

* Fixed :dry_run routine.

0.1.0 (04/13/2013)
==================

* Gem has been renamed -- is now `knife-cookbook-sync`.
* Chef 11 now works, Chef 10 still works.
* Clarified exit statuses for various behavior.

0.0.5
=====

* Deal with resolver bad behavior in a more appropriate way (abort).

0.0.4
=====

* Deal with cookbook sync's exit statuses a little more clearly in the
  chef-workflow task.

0.0.3
=====

* Add chef-workflow support

0.0.2
=====
* honor knife.rb configuration of cookbook path
* add a quiet option (-q). dry run is unaffected.
* check if the cookbook exists before loading it. vastly improves upload
  performance for new cookbooks.
* exploit recent threaded upload improvements in Chef API: 0.1s slower than
  knife cookbook upload for all new content (worst case for sync).

0.0.1
=====

* First public release.
