%%% @author Sergey Prokhorov <me@seriyps.ru>
%%% @copyright (C) 2013, Sergey Prokhorov
%%% @doc
%%%
%%% @end
%%% Created : 28 Jun 2013 by Sergey Prokhorov <me@seriyps.ru>

-module(redirect_middleware_tests).

-include_lib("eunit/include/eunit.hrl").
-include("xhttpc.hrl").
-include("xhttpc_test.hrl").

redirect_303_test() ->
    %% 303 should redirect using GET request
    Se = xhttpc:init([], test_client),
    {ok, St} = redirect_middleware:init([]),
    Opts = [{client_options, [{response, fun term2bin_response/1}]}],
    Req = #xhttpc_request{
      url = "http://example.com/",
      headers = ?NH([{"hdr1", "val1"}]),
      method = post,
      body = <<"post-body">>,
      options = Opts},
    Resp = {ok, {{303, "moved blabla"},
                 ?NH([{"location", "http://example.com/redir"}]),
                 <<"moved">>}},
    {update, _Se1, {ok, {{200, _}, _, BinBody}}, _St1} =
        redirect_middleware:response(Se, Req, Resp, St),
    #xhttpc_request{url = Url,
                    method = Method,
                    headers = Hdrs,
                    options = ResOpts,
                    body = Body} = binary_to_term(BinBody),
    ?assertEqual("http://example.com/redir", Url),
    ?assertEqual(get, Method),
    ?assertEqual(undefined, Body),
    ?assertEqual(?NH([{"hdr1", "val1"}]), Hdrs),
    ?assertEqual(Opts, ResOpts).

redirect_301_302_test_() ->
    %% 301/302 should redirect using the same method/body as original request
    [fun() -> redirect_301_302(301) end,
     fun() -> redirect_301_302(302) end].

redirect_301_302(Code) ->
    Se = xhttpc:init([], test_client),
    {ok, St} = redirect_middleware:init([]),
    Opts = [{client_options, [{response, fun term2bin_response/1}]}],
    RedirUrl = "http://example.com/redir",
    Req = #xhttpc_request{
      url = "http://example.com/",
      headers = ?NH([{"hdr1", "val1"}]),
      method = post,
      body = <<"post-body">>,
      options = Opts},
    Resp = {ok, {{Code, "moved blabla"},
                 ?NH([{"location", RedirUrl}]),
                 <<"moved">>}},
    {update, _Se1, {ok, {{200, _}, _, BinBody}}, _St1} =
        redirect_middleware:response(Se, Req, Resp, St),
    NewReq = binary_to_term(BinBody),
    WaitReq = Req#xhttpc_request{url=RedirUrl},
    ?assertEqual(WaitReq, NewReq).

infinite_redirect_test() ->
    S = xhttpc:init([{redirect_middleware, [{max_depth, 2}]}], test_client),
    Response = {ok, {{301, "moved blabla"},
                 ?NH([{"location", "http://example.com/"}]),
                 <<"moved">>}},
    ?assertError(
       {max_redirect_depth_exceeded, 3, 2},
       xhttpc:request(
         S, #xhttpc_request{url="http://example.com/",
                            options=[{client_options,
                                      [{response, Response}]}]})).
