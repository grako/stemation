Squaw
=====

Blog generator with consideration for good SEO practices.

Setup
-----

Copy dir and contents ``priv-SAMPLE'' to ``priv''

Copy ``include/squaw.hrl.SAMPLE'' over to ``include/squaw.hrl''

Work your files in `priv' to yield the desired blog website.

Set your configuration in ``include/squaw.hrl'' as per the suggested values.

Run `make init` then `make` to generate a public folder that nginx/python/ruby
can serve.


NOTES
-----

See ``priv/posts/*.md'' for specs on how to write a markdown blog-post.

'Can't recall who started this, but in-line code tags are created via
  =code=, and not backtick.

Code blocks are created with new-line and indented with 4 spaces.

    Like:This(Args) ->
        And:this([]).

TODO
----

1. twitter-card/og image metatags
2. funtionize un-nest canonicalize rename seven-ize
  API+Biz+Support
3. documentation

BUGS
----

1. list item adds <p> to last item if there is a line break
2. new line after iframe WTF
3. allow <valid-tag>inline</valid-tag> with no \n in her
4. <link rel="canonical" href="http://www.frontendjournal.com/javascript-es6-learn-important-features-in-a-few-minutes/"/>
5. incorporate armstrong don't include whole jaunt
