-module(yaws_websocket_test).

-include_lib("eunit/include/eunit.hrl").
-include("../../include/yaws_api.hrl").

%% for spawn
-export([client/2, acceptor/1]).

%%===================================================================
%% Basic successful handshake test.
%%===================================================================
start_test() ->
    %% Accept the connection and call yaws_websockets:start/3 in
    %% another process so that the test process doesn't get exited.
    AcceptorPid = spawn_link(?MODULE, acceptor, [self()]),
    receive
        {server_port, ServerPort} ->
            ok
    end,
    ClientPid = spawn_link(?MODULE, client, [self(), ServerPort]),

    receive
        {client_tcp, Data} ->
            %% check the response was what it should be
            Expected =
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
            ?assertEqual(Expected, Data)
    end,

    ClientPid ! exit.


acceptor(TestPid) ->
    {ok, ListenSock} = gen_tcp:listen(0, []),
    {ok, ServerPort} = inet:port(ListenSock),
    TestPid ! {server_port, ServerPort},
    {ok, ServerSock} = gen_tcp:accept(ListenSock),
    gen_tcp:close(ListenSock),
    Arg = mk_arg(ServerSock),
    CallbackMod = undefined,
    Opts = [],
    yaws_websockets:start(Arg, CallbackMod, Opts).

client(TestPid, ServerPort) ->
    {ok, ClientSock} = gen_tcp:connect("localhost", ServerPort, []),
    receive % wait for handshake response
        {tcp, ClientSock, Data} ->
            TestPid ! {client_tcp, Data}
    end.

mk_arg(Socket) ->
    %% The tuples tagged 'http_header' are as given by erlang:decode_packet/3
    Other = [{http_header,0,"Sec-WebSocket-Version",undefined,"13"},
              {http_header,0,"Sec-Websocket-Key",undefined,
               "dGhlIHNhbXBsZSBub25jZQ=="},
              {http_header,0,"Origin",undefined,"http://example.com"},
              {http_header,6,'Upgrade',undefined,"websocket"}],
    Headers = #headers{other = Other},
    #arg{clisock = Socket,
         headers = Headers}.
