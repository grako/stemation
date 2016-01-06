gen:	compile
	@echo "*** N.B. Does vim have any html files open? \nErlang will fail if so."
	rm -fr public
	erl -noshell -pz ebin -eval 'squaw:start().' -s init stop
	cp -r ./priv/assets ./public/assets

t:	compile
	@echo "N.B. -noshell uses latin1, so won't io:format chars > 255"
	erl -noshell -pz ebin -s squaw_misc test -s squaw_markdown test -s init stop
cover:	compile
	@echo "*** N.B. Does vim have any html files open? \nErlang will fail if so."
	rm -fr public
	erl -noshell -pz ebin \
	  -s cover \
	  -eval 'cover:compile("src/squaw.erl").' \
	  -s squaw \
	  -eval 'timer:sleep(3000).' \
	  -eval 'cover:analyse_to_file(squaw).' \
	  -s init stop
	cp -r ./priv/assets ./public/assets
init:
	rm -fr ebin
	mkdir ebin
compile:
	@erlc +bin_opt_info -o ebin src/*.erl
help:
	@echo 'Run tests with `make t` or run the generator `make gen`'
ping:
	curl -I "http://bing.com/webmaster/ping.aspx?siteMap=http://stemation.com/sitemap.xml"
	curl -I "http://www.google.com/webmasters/sitemaps/ping?sitemap=http://stemation.com/sitemap.xml"
