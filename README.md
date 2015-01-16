## VmStats Probe

An [escript](http://www.erlang.org/doc/man/escript.html) to inject, at runtime, instrumentation into a remote [BEAM (Erlang) virtual machine](http://www.erlang.org/) using [vmstats](https://github.com/ferd/vmstats) and [StatsD](https://github.com/ferd/vmstats). A VM instrumented in this way will output stats to a StatsD server, until restarted.

## Prereqs

Erlang.

```
brew install erlang
```

## Caveats

Scheduler Wall clock statistics are disabled by default due to instability issues on certain Erlang versions. See the [upstream docs](https://github.com/ferd/vmstats#why-scheduler-wall-time-statistics-disabled-by-default)

## Usage

The most excellent [getopt](https://github.com/jcomellas/getopt) library provides cli help.

```
~$ ./vmstats_probe
Vmstats Probe :: Adding statsd to your beam since 2015
Usage: ./vmstats_probe [<node>] [-l [<lolcat>]] [-c <cookie>]
[--statsd-ip [<statsd>]] [-s [<names>]]
[-p [<port>]]
[-w [<wall>]]

<node>             Remote erlang VM node name
-l, --lolz         Print erlang lolcat [default: false]
-c, --cookie       Provide a cookie, if needed, to connect to remote node
--statsd-ip        the IP address of StatsD UDP server. See the docs for inet:parse_address/1 for more. [default: 127.0.0.1]
-s, --shortnames   Use short node names [default: false]
-p, --statsd-port  StatsD UDP port number [default: 8125]
-w, --enable-wall  Enable Scheduler Wall-Clock Statistics - warning, may cause instability [default: false]
```

Examples:

Long Names:
```
./vmstats_probe --statsd-ip "10.199.103.168" farawaynode@server.example.org
Starting net_kernel, using longnames...
Started net_kernel, connecting to farawaynode@server.example.org...
Connected successfully! Loading modules...
Remote loading completed! Starting statistics applications...
Remote application start completed, output was:
[ok,ok,ok,ok,ok,ok,ok,ok,ok,ok]
```

Short Names:
```
./vmstats_probe --statsd-ip "127.0.0.1" -s target@`hostname -s`
Starting net_kernel, using shortnames...
Started net_kernel, connecting to target@BRADS_MACBOOK...
Connected successfully! Loading modules...
Remote loading completed! Starting statistics applications...
Remote application start completed, output was:
[ok,ok,ok,ok,ok,ok,ok,ok,ok,ok]
```

Error Message if unable to connect to remote node with longnames:
```
./vmstats_probe --statsd-ip "127.0.0.1" target@fakehost.notarealdomain.org
Starting net_kernel, using longnames...
Started net_kernel, connecting to target@fakehost.notarealdomain.org...
Node name "'target@fakehost.notarealdomain.org'" not reachable.
Ensure the remote node's host name is reachable from this host using DNS, and check that the remote epmd service is available from this host using telnet.
```

Error Message if unable to connect to remote node with shortnames:
```
./vmstats_probe --statsd-ip "127.0.0.1" -s target
Starting net_kernel, using shortnames...
Started net_kernel, connecting to target...
Node name "target" not reachable.
Ensure the remote node is using short names, and has "@BRADS_MACBOOK" at the end.
```

For the StatsD IP address, use a string parseable by the [inet erlang library](http://www.erlang.org/doc/man/inet.html).
```
./vmstats_probe --statsd-ip "{127,0,0,1} bad arg." -s target@`hostname -s`
Unable to parse StatsD IP address config.
```

## How do I remove the remote-loaded code from the remote node?

At this time, you don't - you *must* restart the remote VM. The change to add
the code to the VM isn't persisted to disk, so a restart will wipe it clean.
It will be possible to add remote *uninstallation* functionality in a later
release.

## Building

```
rebar get-deps clean compile escriptize && ./vmstats_probe
```

### Compatibility

This script was (manually) tested on:

- Erlang R15B01, platform: Darwin
- Erlang R15B03, platform: Darwin
- Erlang R16B03-1, platform: Darwin
- Erlang 17.4, platform: Darwin

I would expect mixing different runtime versions and platforms for the escript itself and the remote target of the escript will get bad results, but you never know. Of course, YMMV.

### Props List

Fred Herbert -> creator of epic awesome Erlang libraries [recon](https://github.com/ferd/recon) and [vmstats](https://github.com/ferd/vmstats)

Etsy         -> creator of [StatsD](https://github.com/etsy/statsd)
