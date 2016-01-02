%% -*- coding: utf-8 -*-
-module(squaw_misc).

-export([smart/1,
         padded_date/1,
         w3_datetime/1,
         bytewise_binary_to_list/1,
         test/0]).

-define(patterns,[{<<$-,$->>,<<"—"/utf8>>},
                  {<<$.,$.,$.>>,<<"…"/utf8>>},
                  {<<$`,$`>>,<<"“"/utf8>>},
                  {<<$',$'>>,<<"”"/utf8>>},
                  {<<$'>>,<<"’"/utf8>>},
                  {<<$`>>,<<"‘"/utf8>>}]).

padded_date({Y,M,D}) ->
    padded_date_acc([Y,M,D],[]).

padded_date_acc([H|T],Acc) ->
    Bin = integer_to_binary(H),
    H1  = maybe_zeropad(Bin),
    padded_date_acc(T,[H1|Acc]);
padded_date_acc([],[D,M,Y]) -> {Y,M,D}.

maybe_zeropad(X) when size(X) =/= 1 -> X;
maybe_zeropad(X) -> <<$0,X/bitstring>>.

w3_datetime({Y,M,D}) ->
    <<Y/bitstring,$-,
      M/bitstring,$-,
      D/bitstring,$T,
      "13:00:00+00:00">>.

%% TODO allow escaping
smart(B) ->
    lists:foldl(fun global_replace/2,B,?patterns).

bytewise_binary_to_list(B) ->
    Try = unicode:characters_to_list(B),
    maybe_bytewise_binary_to_list(B,Try).

maybe_bytewise_binary_to_list(_,Res) when is_list(Res) -> Res;
maybe_bytewise_binary_to_list(B,_) ->
    binary_to_list(B).

global_replace({P,R},X) -> binary:replace(X,P,R,[global]). 

% sanity tests
test() -> 
    W3 = fun w3_datetime/1,
    T = {<<"2012">>,<<"09">>,<<"29">>},
    <<"2012-09-29T13:00:00+00:00">> = W3( T ),
    Date = fun padded_date/1,
    Zeros = {2012,9,9},
    {<<"2012">>,<<"09">>,<<"09">>} = Date( Zeros ),
    Mbb2l = fun bytewise_binary_to_list/1,
    A = smart(<<"this' `thing -- ">>),
    "this’ ‘thing — " = Mbb2l(A),
    B = smart(<<"this' ...-- `thing -- - -....">>),
    "this’ …— ‘thing — - -…." = Mbb2l(B),
    C = smart(<<"``quotes'' should `jaunt.'">>),
    "“quotes” should ‘jaunt.’" = Mbb2l(C),
    D = smart(<<"``quotes'' should `jaunt', said Eugène Ysaÿe."/utf8>>),
    "“quotes” should ‘jaunt’, said Eugène Ysaÿe." = Mbb2l(D),
    E = smart(<<>>),
    E = <<>>,
    void.
