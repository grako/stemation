%% pages:
%% only include pages found in priv/ *other* than 404.html, 
%% index.html, _footer.html, _header.html, posts/* assets/*
%% for example -> ["faq","contact"] 
%% can be -> [] 
-define(pages,[]). 

%% title:
%% meta + page title for general pages.
-define(title,"STEMation - The Future of STEM").

%% description:
%% meta description for general pages.
-define(description,"STEMation is a blog exploring what is working to improve diversity in STEM.").

%% url:
%% *base* url needed for this and that.
%% N.B. the url should end with the domain suffix, not "/"
-define(url,"http://stemation.com").

%% path:
%% directory and url path for your posts (eg. foo.com/blog)
%% N.B. the path should not contain "/" and has to be one word.
-define(path,"blog").

%% appendage:
%% can be "" or "Any Html" and will show up on the footer of blog posts.
%% great for social links, etc..
-define(appendage,"<p class='appendage'>&#9758; <a href='//twitter.com/stemation'>follow on twitter</a></p>").
