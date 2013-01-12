0.0.2
=====
* honor knife.rb configuration of cookbook path
* add a quiet option (-q). dry run is unaffected.
* check if the cookbook exists before loading it. vastly improves upload performance for new cookbooks.
* exploit recent threaded upload improvements in Chef API: 0.1s slower than knife cookbook upload for all new content (worst case for sync).

0.0.1
=====

* First public release.
