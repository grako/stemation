-module(squaw).
-include_lib("include/squaw.hrl").

%% API
-export([start/0]).

%% usage: ?NYI({f,attr1,attrn})
-define(NYI(X),(begin
            io:format("*** NYI ~p ~p ~p~n.",[?MODULE,?LINE,X]),
            exit(nyi)
        end)).
-record(meta,{media,title,summary}).
-record(post,{fileroot,slug,date,meta=#meta{}}).

-define(PAGES,        ([ list_to_bitstring(X) || X <- ?pages ])).
-define(PRIV_DIR,     <<"priv">>).
-define(PUBLIC_DIR,   <<"public">>).
-define(DEFAULT_TITLE,(list_to_binary(?title))).
-define(DEFAULT_DESC, (list_to_binary(?description))).
-define(DEFAULT_URL,  (list_to_binary(?url))).
-define(POST_FOOT,    (list_to_binary(?appendage))).
-define(PATH,         (list_to_binary(?path))).

%%%===================================================================
%%% api functions
%%%===================================================================

%% OPTIMIZE tear up/down the public structure (rather than make do it)
start() ->
    ok             = init(),
    {ok,{P,Hd,Ft}} = init(content),
    ok             = handle_site(P,Hd,Ft).

%%%===================================================================
%%% business functions
%%%===================================================================

init() ->
    MkFn = fun make_public_dir/1,
    [ MkFn(X) || X <- [<<"">>,<<"/",?PATH/bitstring>>] ],
    [ MkFn([<<$/>>,X]) || X <- ?PAGES ],
    ok.

init(content) ->
    {ok,P}   = new(posts),
    {ok,H,F} = new(head_foot),
    {ok,{P,H,F}}.

new(head_foot) ->
    {ok,H} = new(header),
    {ok,F} = new(footer),
    {ok,H,F};
new(header) ->
    handle_file(read,[?PRIV_DIR,<<"/_header.html">>]);
new(footer) ->
    handle_file(read,[?PRIV_DIR,<<"/_footer.html">>]);
new(posts) ->
    PD       = [?PRIV_DIR,<<"/posts">>],
    Posts    = sorted_posts(PD),
    Terms    = [ handle_data(P,PD,?PUBLIC_DIR) || P <- Posts ],
    {ok,Terms}.

handle_file(read,F) ->
    F1 = iolist_to_binary(F),
    file:read_file(F1);
handle_file(write,{F,C}) ->
    F1     = iolist_to_binary( F ),
    {ok,H} = file:open(F1,[append,{encoding,utf8}]),
    ok     = io:put_chars(H,C),
    ok     = file:close(H).

handle_site(Posts,H,F) ->
    spawn_link(fun() -> handle_posts(Posts,H,F) end),
    spawn_link(fun() -> handle_sitemap(Posts) end),
    spawn_link(fun() -> handle_robots() end),
    spawn_link(fun() -> handle_blog_index(Posts,H,F) end),
    spawn_link(fun() -> handle_aux_pages(H,F) end),
    ok.

handle_posts(P,H,F) ->
    [ spawn_link(fun() -> handle_post(X,H,F) end) || X <- P ].

handle_robots() ->
    C = robots_txt_content(),
    handle_file(write,{[?PUBLIC_DIR,<<"/robots.txt">>],C}).

handle_sitemap(Posts) ->
    Pages  = sitemap_xml_content(),
    Posts1 = [ sitemap_xml_content({post,X}) || X <- Posts ],
    Tags   = iolist_to_binary([Pages,Posts1]),
    C      = tilda_swap('xml~',Tags),
    handle_file(write,{[?PUBLIC_DIR,<<"/sitemap.xml">>],C}).

%%%% O_o
handle_blog_index(Posts,Hd,Ft) ->
    Titles = blog_titles(Posts),
    PageFn = fun assemble/1,
    spawn_link(
      PageFn(
        {{data,Titles},
         [?PUBLIC_DIR,<<"/",?PATH/bitstring,"/index.html">>],Hd,Ft})).

%%%% O_o
handle_post(#post{fileroot=FileR,
                  slug=Slug,
                  date={_,M,D},
                  meta=#meta{title=Title,
                             summary=Summary}},Hd,Ft) ->
    {ok,Main} = post_html(FileR,Title,{M,D}),
    PathA     = [<<"/",?PATH/bitstring,"/">>,Slug,<<".html">>],
    Url       = iolist_to_binary([?DEFAULT_URL|PathA]),
    Hd1       = apply_phases([{titles,Title},
                              {descriptions,Summary},
                              {urls,Url}],Hd),
    {A,Z}     = tags('article'),
    handle_file(write,{[?PUBLIC_DIR|PathA],[Hd1,A,Main,Z,Ft]}).

%%%% O_o
handle_aux_pages(Hd,Ft) ->
    PFn    = fun assemble/1,
    PathsX = url_paths(),
    PathsY = [ url_paths(X) || X <- ?PAGES ],
    PathsZ = [ N || L <- [PathsX,PathsY], N <- L ], % i.e. append
    [ spawn_link(
      PFn({[?PRIV_DIR,F],[?PUBLIC_DIR,T],Hd,Ft})) || 
        {F,T} <- PathsZ ].

%%%% O_o this does 2 things, XXX
handle_data(F,A,Z) ->
    {ok,{F1,S,D}} = extract(F),
    A1            = handle_data(path,[A,<<"/">>,F]), 
    Z1            = handle_data(path,[Z,<<"/">>,F1,<<".tmp">>]),

    {meta,Meta}   = squaw_markdown:collect_meta_conv_file(A1,Z1),
    {ok,{T,S1,M}} = post_meta(Meta),
    Meta1         = #meta{title=T,summary=S1,media=M},
    #post{fileroot=F1,slug=S,date=D,meta=Meta1}.

handle_data(path,P) -> iolist_to_binary(P).

handle_tmpfile(F) ->
    TmpLoc = [?PUBLIC_DIR,<<$/>>,F,<<".tmp">>],
    Res    = {ok,_} = handle_file(read,TmpLoc),
    destroy_tmpfile(TmpLoc),
    Res.

%%%===================================================================
%%% support functions
%%%===================================================================

extract(F) ->
    F1  = filename:rootname(F),
    Bin = list_to_bitstring(F1),
    <<Y:32/bitstring,$-,M:16/bitstring,
      $-,D:16/bitstring,$-,S/bitstring>> = Bin,
    {ok,{F1,S,{Y,M,D}}}.

post_html(F,T,{M,D}) ->
    DT        = post_date(M,D),
    T1        = tilda_swap('h2~',T),
    {ok,Html} = handle_tmpfile(F),
    {ok,[DT,T1,Html,?POST_FOOT]}.

post_meta(M) ->
    T  = title(M),
    S  = summary(M),
    M1 = is_media(M),
    {ok,{T,S,M1}}.

post_date(M,D) ->
    PM   = pretty({month,M}),
    PD   = pretty({day,D}),
    Date = <<PM/bitstring," ",PD/bitstring>>,
    tilda_swap('date~',Date).

title(M) ->
    {title,T} = lists:keyfind(title,1,M),
    T1        = unicode:characters_to_binary(T),
    squaw_misc:smart(T1).

summary(M) ->
    {summary,S} = lists:keyfind(summary,1,M),
    S1          = unicode:characters_to_binary(S),
    squaw_misc:smart(S1).

is_media(M) ->
    Q = lists:keyfind(media,1,M),
    maybe_media(Q).

maybe_media({media,true}) -> true;
maybe_media(false) -> false.

url_paths() ->
    [{<<"/index.html">>,<<"/index.html">>},
     {<<"/404.html">>,<<"/404.html">>}].

url_paths(X) ->
    {[<<$/>>,X,<<".html">>],
     [<<$/>>,X,$/,<<"index.html">>]}.

sitemap_xml_content() ->
    DT   = sitemap_xml_content(datetime),
    Urls = sitemap_xml_content(urls),
    [ sitemap_xml_content(U,DT) || U <- Urls ].

%%%% O_o
sitemap_xml_content(urls) ->
    Main  = [[<<$/>>],[<<"/",?PATH/bitstring>>]],
    Other = [ [<<$/>>,X] || X <- ?PAGES ],
    All   = [ [?DEFAULT_URL,N] || L <- [Main,Other], N <- L ],
    [ iolist_to_binary(U) || U <- All ];
sitemap_xml_content(datetime) ->
    Today = erlang:date(),
    Date  = squaw_misc:padded_date(Today),
    squaw_misc:w3_datetime(Date);
sitemap_xml_content({post,#post{slug=S,date=Date}}) ->
    DT  = squaw_misc:w3_datetime(Date),
    Url = iolist_to_binary(
      [?DEFAULT_URL,<<"/",?PATH/bitstring,"/">>,S,<<".html">>]),
    sitemap_xml_content(Url,DT).

sitemap_xml_content(Url,DT) ->
    Loc1     = tilda_swap('loc~',Url),
    LastMod1 = tilda_swap('lastmod~',DT),
    {A,Z}    = tags(url),
    [A,Loc1,LastMod1,Z].

assemble({{data,D},To,Hd,Ft}) ->
    fun() ->
        Hd1 = apply_phases([{titles,?DEFAULT_TITLE},
                            {descriptions,?DEFAULT_DESC},
                            {urls,?DEFAULT_URL}],Hd),
        ok  = handle_file(write,{To,[Hd1,D,Ft]})
    end;
assemble({From,To,Head,Foot}) ->
    {ok, Cont} = handle_file(read,From),
    assemble({{data,Cont},To,Head,Foot}).

blog_titles(Posts) ->
    Dates  = [ X#post.date || X <- Posts ],
    Years  = blog_years(Dates),
    Titles = [ blog_titles(Y,Posts) || Y <- Years ],
    iolist_to_binary(Titles).

blog_years(D) ->
    A  = [ X || {X,_,_} <- D ],
    A1 = lists:usort(A),
    lists:reverse(A1).

blog_titles(Year,Posts) ->
    YrPosts = lists:filter(
                fun(X) -> is_given_year({Year,X}) end, Posts),
    Content = [ blog_title(X) || X <- YrPosts ],
    Bin     = iolist_to_binary(Content),
    Head    = tilda_swap('h2~',Year),
    <<Head/bitstring,Bin/bitstring>>.

blog_title(#post{slug=Slug,meta=#meta{title=Title,media=Media}}) ->
    {A,Z}   = tags('div'),
    {MA,MZ} = media_spans(Media),
    Title1  = unicode:characters_to_binary(Title),
    SmartT  = squaw_misc:smart(Title1),
    Link    = blog_link(Slug,SmartT),
    [A,MA,Link,MZ,Z].

blog_link(S,T) ->
    [<<"<a href='/",?PATH/bitstring,"/">>,
      S,<<".html'>">>,T,<<"</a>\n">>].

is_given_year({Y,#post{date={Y,_,_}}}) -> true;
is_given_year(_) -> false.

media_spans(true) ->
    A = <<"<span class='link-icons'>">>,
    Z = <<"<span class='icon itunes charm'>i</span></span>\n">>,
    {A,Z};
media_spans(false) -> 
    tags(span).

meta_swap({urls,U,C}) ->
    Pairs = [
              {<<"fb-url">>,
               <<"<meta property=\"og:url\" content=\"", 
                 U/bitstring, "\" />">>},
              {<<"twitter-url">>,
               <<"<meta name=\"twitter:url\" content=\"", 
                 U/bitstring, "\" />">>}
            ],
    meta_swap(Pairs,C);
meta_swap({titles,T,C}) ->
    Pairs = [
              {<<"fb-title">>,
               <<"<meta property=\"og:title\" content=\"", 
                 T/bitstring, "\" />">>},
              {<<"twitter-title">>,
               <<"<meta name=\"twitter:title\" content=\"", 
                 T/bitstring, "\" />">>},
              {<<"meta-title">>,
               <<"<meta name=\"title\" content=\"", 
                 T/bitstring, "\" />">>},
              {<<"title">>,
               <<"<title>", T/bitstring, "</title>\n">>}
            ],
    meta_swap(Pairs,C);
meta_swap({descriptions,D,C}) ->
    Pairs = [
              {<<"fb-description">>,
               <<"<meta property=\"og:description\" content=\"", 
                 D/bitstring, "\" />">>},
              {<<"twitter-description">>,
               <<"<meta name=\"twitter:description\" content=\"", 
                 D/bitstring, "\" />">>},
              {<<"meta-description">>,
               <<"<meta name=\"description\" content=\"", 
                 D/bitstring, "\" />">>}
            ],
    meta_swap(Pairs,C).

meta_swap(L,C) ->
    SwapFn = tilda_swap('swap~'),
    meta_swap_acc(L,SwapFn,C).

meta_swap_acc([{Old,New}|T],SwapFn,Acc) ->
    Old1 = SwapFn(Old),
    Acc1 = binary:replace(Acc,Old1,New),
    meta_swap_acc(T,SwapFn,Acc1);
meta_swap_acc([],_,Acc) -> Acc.

tilda_swap(Old) ->
    fun(New) -> tilda_swap(Old,New) end.

tilda_swap(X,New) when is_atom(X) ->
    Old = tag(X),
    tilda_swap(Old,New);
tilda_swap(Old,New) ->
    binary:replace(Old,<<$~>>,New).

pretty({month,X}) -> p_m(X);
pretty({day,X})   -> p_d(X).

p_m(<<"01">>) -> <<"jan">>;
p_m(<<"02">>) -> <<"feb">>;
p_m(<<"03">>) -> <<"mar">>;
p_m(<<"04">>) -> <<"apr">>;
p_m(<<"05">>) -> <<"may">>;
p_m(<<"06">>) -> <<"jun">>;
p_m(<<"07">>) -> <<"jul">>;
p_m(<<"08">>) -> <<"aug">>;
p_m(<<"09">>) -> <<"sep">>;
p_m(<<"10">>) -> <<"oct">>;
p_m(<<"11">>) -> <<"nov">>;
p_m(<<"12">>) -> <<"dec">>.

p_d(<<"01">>) -> <<"1">>;
p_d(<<"02">>) -> <<"2">>;
p_d(<<"03">>) -> <<"3">>;
p_d(<<"04">>) -> <<"4">>;
p_d(<<"05">>) -> <<"5">>;
p_d(<<"06">>) -> <<"6">>;
p_d(<<"07">>) -> <<"7">>;
p_d(<<"08">>) -> <<"8">>;
p_d(<<"09">>) -> <<"9">>;
p_d( K )      -> K.

tags(W) -> 
    O = tag({W,open}),
    C = tag({W,close}),
    {O,C}.

tag('h2~')           -> <<"<h2>~</h2>\n">>;
tag('loc~')          -> <<"<loc>~</loc>\n">>;
tag('swap~')         -> <<"<!--***~***-->">>;
tag('date~')         -> <<"<div class='date'><abbr>~</abbr></div>\n">>;
tag('lastmod~')      -> <<"<lastmod>~</lastmod>\n">>;
tag({url,open})      -> <<"<url>\n">>;
tag({url,close})     -> <<"</url>\n">>;
tag({span,open})     -> <<"<span>">>;
tag({span,close})    -> <<"</span>\n">>;
tag({'div',open})    -> <<"<div>\n">>;
tag({'div',close})   -> <<"</div>\n">>;
tag({article,open})  -> <<"<article>\n">>;
tag({article,close}) -> <<"</article>\n">>;
tag('xml~') -> 
  <<"<?xml version='1.0' encoding='utf-8'?>\n",
    "<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>\n", 
    "~</urlset>">>.

destroy_tmpfile(X) ->
    X1 = iolist_to_binary(X),
    spawn_link(fun() -> file:delete(X1) end).

make_public_dir(N) -> 
    N1 = iolist_to_binary([?PUBLIC_DIR,N]),
    ok = file:make_dir(N1).

sorted_posts(D) ->
    D1 = iolist_to_binary(D),
    {ok,P} = file:list_dir(D1),
    P1 = lists:sort(P),
    lists:reverse(P1).

robots_txt_content() ->
    [<<"User-agent: *\nSitemap: ">>, 
     ?DEFAULT_URL,<<"/sitemap.xml">>].

apply_phases([{X,Y}|Rest],A) ->
    A1 = meta_swap({X,Y,A}), 
    apply_phases(Rest,A1);
apply_phases([],A) -> A.
