% Copyright 2015 Bradley Rowe
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
% http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
-module(vmstats_probe).

-export([main/1]).

-define(TIMEOUT, 120000).
-define(PRINT(Statement),
        io:format("~w~n",[Statement])).


statsderl(IpAddress, Port) ->
    {application, statsderl, [
                              {description, "StatsD client"},
                              {vsn, "0.3.5"},
                              {registered, []},
                              {applications, [
                                              kernel,
                                              stdlib
                                             ]},
                              {mod, {statsderl_app, []}},
                              {env, [
                                     {hostname, IpAddress},
                                     {port, Port}
                                    ]}
                             ]}.


vmstats(SchedTime)->
    {application, vmstats, [
                            {description, "Tiny application to gather VM statistics for StatsD client"},
                            {vsn, "1.0.1"},
                            {registered, [vmstats_sup, vmstats_server]},
                            {applications, [
                                            kernel,
                                            stdlib,
                                            statsderl
                                           ]},
                            {mod, {vmstats, []}},
                            {applications, [statsderl]},
                            {modules, [vmstats, vmstats_sup, vmstats_server]},
                            {env, [
                                   {base_key, "vmstats"},
                                   {delay, 1000}, % in milliseconds
                                   {sched_time, SchedTime}
                                  ]}
                           ]}.

option_spec_list() ->
  [
    {node,    undefined, undefined,       atom,                     "Remote erlang VM node name"},
    {lolcat,  $l,        "lolz",          {boolean, false},         "Print erlang lolcat"},
    {cookie,  $c,        "cookie",        atom,                     "Provide a cookie, if needed, to connect to remote node"},
    {statsd,  undefined, "statsd-ip",     {string,"127.0.0.1"},     "the IP address of StatsD UDP server. See the docs for inet:parse_address/1 for more."},
    {names,   $s,        "shortnames",    {boolean, false},         "Use short node names"},
    {port,    $p,        "statsd-port",   {integer, 8125},          "StatsD UDP port number"},
    {wall,    $w,
              "enable-scheduler-stats",   {boolean, false},         "Enable Scheduler Wall-Clock Statistics - WARNING, may cause instability"}
  ].


help() ->
    io:format("Vmstats Probe :: Adding statsd to your beam since 2015~n"),
    Params = [
        {"", ""}
      ] ,
    getopt:usage(option_spec_list(), escript:script_name(), "", Params),
    halt().

main([]) ->
    help();

main(["-h"| _]) ->
    help();

main(["--help"| _]) ->
    help();

main(Args) ->
    Opts =  case getopt:parse(option_spec_list(), Args) of
              {ok, {O, _}} -> O;
              {error, {_,_}} ->
                io:format("Unable to parse these command line args: ~p~n~n",[Args]),
                help(),
                halt()
            end,
    case proplists:get_value(lolcat, Opts) of
      true ->   print_lolcat(),
                halt();
      false ->  ok
    end,
    Port = proplists:get_value(port, Opts),
    RemoteNode =  case proplists:get_value(node, Opts) of
                       undefined ->  io:format("Please supply a remote VM name on the command line!~n~n"),
                                     help(),
                                     halt();
                       N -> N
                  end,
    IpAddress = case  inet:parse_address(proplists:get_value(statsd, Opts)) of
                        {ok, IpAddr} -> IpAddr;
                        {error, _} ->
                            io:format("Unable to parse StatsD IP address config.~n"),
                            halt()
                      end,
    Names = case proplists:get_value(names, Opts) of
      true  -> shortnames;
      false -> longnames
    end,
    SchedTime = proplists:get_value(wall, Opts),
    io:format("Starting net_kernel, using ~w...~n", [Names]),
    {ok, _Pid} = net_kernel:start(['vmstats_snoop', Names]),
    io:format("Started net_kernel, connecting to ~s...~n", [RemoteNode]),
    case proplists:get_value(cookie, Opts) of 
      undefined ->
        ok;
      C when is_atom(C) ->
        true = erlang:set_cookie(node(), C)
    end,
    case net_kernel:connect_node(RemoteNode) of
      true ->   ok;
      false ->  io:format("Node name \"~w\" not reachable.~n", [RemoteNode]),
                case Names of
                  shortnames ->
                    {ok, Host} = inet:gethostname(),
                    io:format("Ensure the remote node is using short names, and has \"@~s\" at the end.~n",[Host]),
                    halt();
                  longnames  ->
                    io:format("Ensure the remote node's host name is reachable from this host using DNS, "),
                    io:format("and check that the remote epmd service is available from this host using telnet.~n"),
                    halt()
                end
    end,
    io:format("Connected successfully! Loading modules...~n"),
    recon:remote_load(recon),
    recon:remote_load(recon_alloc),
    recon:remote_load(recon_lib),
    recon:remote_load(recon_trace),
    recon:remote_load(statsderl),
    recon:remote_load(statsderl_app),
    recon:remote_load(statsderl_sup),
    recon:remote_load(vmstats),
    recon:remote_load(vmstats_server),
    recon:remote_load(vmstats_sup),
    recon:remote_load(vmstats_probe),
    io:format("Remote loading completed! Starting statistics applications...~n"),
    {List1,_} = recon:rpc(fun () -> application:load(statsderl(IpAddress, Port)) end),
    {List2,_} = recon:rpc(fun () -> application:load(vmstats(SchedTime)) end),
    {List3,_} = recon:rpc(fun () -> application:set_env(statsderl, base_key, name) end),
    {List4,_} = recon:rpc(fun () -> application:start(statsderl) end),
    {List5,_} = recon:rpc(fun () -> application:start(vmstats) end),
    io:format("Remote application start completed, output was: ~n~p~n", [List1 ++ List2 ++ List3 ++ List4 ++ List5]),
    halt().

print_lolcat() ->
    io:format("              |\\__/,|   (`\\        _.-|   |          |\\__/,|   (`\" ~n"),
    io:format("              |o o  |__ _) )      {   |   |          |o o  |__ _) ) ~n"),
    io:format("            _.( T   )  `  /        \"-.|___|        _.( T   )  `  / ~n"),
    io:format("  n n._    ((_ `^--' /_<  \\         .--'-`-.     _((_ `^--' /_<  \\ ~n"),
    io:format("  <\" _ }=- `` `-'(((/  (((/       .+|______|__.-||__)`-'(((/  (((/ ~n"),
    io:format("~n       I'm in ur beam, pushing ur statz !!1one~n").
