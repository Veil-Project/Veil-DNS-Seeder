veil-seeder
==============

Veil-seeder is a crawler for the Veil network, which exposes a list
of reliable nodes via a built-in DNS server.

This is what a DNS seed in `chainparams.cpp` should be answered by: a
hostname whose addresses are discovered and re-tested continuously,
rather than an A record somebody has to remember to update. A running
instance serves `seed.veil-info.org`.

Features:
* regularly revisits known nodes to check their availability
* bans nodes after enough failures, or bad behaviour
* keeps statistics over (exponential) windows of 2 hours, 8 hours,
  1 day and 1 week, to base decisions on.
* very low memory (a few tens of megabytes) and cpu requirements.
* crawlers run in parallel (by default 96 threads simultaneously).

One process serves one network. Add `--testnet` for a testnet crawler;
it needs its own hostname and its own UDP 53 endpoint, so a second
instance means a second address or a second host.

REQUIREMENTS
------------

$ sudo apt-get install build-essential libboost-all-dev libssl-dev

USAGE
-----

Assuming you want to run a dns seed on dnsseed.example.com, you will
need an authorative NS record in example.com's domain record, pointing
to for example vps.example.com:

$ dig -t NS dnsseed.example.com

;; ANSWER SECTION
dnsseed.example.com.   86400    IN      NS     vps.example.com.

On the system vps.example.com, you can now run dnsseed:

./dnsseed -h dnsseed.example.com -n vps.example.com

If you want the DNS server to report SOA records, please provide an
e-mail address (with the @ part replaced by .) using -m.

COMPILING
---------
Compiling will require boost and ssl.  On debian systems, these are provided
by `libboost-dev` and `libssl-dev` respectively.

$ make

This will produce the `dnsseed` binary.


If Boost or OpenSSL live outside the default prefix, pass the paths in
rather than replacing CXXFLAGS:

$ make CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib"


PROTOCOL VERSION
----------------

`PROTOCOL_VERSION` in `serialize.h` must be at least the node's
`MIN_PEER_PROTO_VERSION_AFTER_ENFORCEMENT` (`src/version.h` in
Veil-Project/veil). Nodes reject and disconnect any peer advertising
less than that minimum, so a stale value here silently stops the
crawler from reaching anything. Raise it whenever the node raises its
minimum.


RUNNING AS NON-ROOT
-------------------

Typically, you'll need root privileges to listen to port 53 (name service).

One solution is using an iptables rule (Linux only) to redirect it to
a non-privileged port:

$ iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353

If properly configured, this will allow you to run dnsseed in userspace, using
the -p 5353 option.

On systemd distributions the redirect is the better option regardless.
systemd-resolved holds 127.0.0.53:53, so binding 0.0.0.0:53 collides with
it, and disabling its stub listener breaks name resolution for everything
else on the box - including any Veil node running alongside. Redirecting
leaves resolved untouched. Persist the rule (iptables-persistent, or
`netfilter-persistent save`) or it disappears on reboot.


DEPLOYING
---------

The host needs a public IP, UDP 53 reachable, and an NS delegation
pointing the seed hostname at it. Two DNS records are required, an
address for the nameserver itself and the delegation to it:

  ns1.example.com.    A     198.51.100.10
  dnsseed.example.com. NS   ns1.example.com.

A plain A record on the seed name is not enough; without the NS record
queries never reach this process. Behind a CDN, both records must be
DNS-only - a proxied record does not forward UDP.

Check with the provider that inbound UDP 53 is actually allowed. Many
hosts filter it by default to discourage open resolvers, and an
authoritative server for your own zone usually has to be requested.

With the delegation in place:

$ ./dnsseed -h dnsseed.veil-project.com -n vps.veil-project.com -m admin.veil-project.com -t 16

`-t 96` is sized for a network with thousands of nodes; on Veil's
current network 16 threads is plenty.

The first pass takes several minutes to show anything. One crawler
thread claims up to 16 addresses and works them in sequence, and results
are only recorded once the whole batch finishes, so the counters sit at
`0 tried` with everything `active` for the first five to ten minutes.
That is normal, not a hang. Once a pass completes the display settles
into something like:

  9/53 available (53 tried in 881s, 0 new, 0 active), 0 banned

Then check that it answers:

$ dig +short @localhost -p 5353 dnsseed.veil-project.com

Each query returns a random subset of the good addresses, so repeated
lookups deliberately return different answers.

State lives in the working directory: `dnsseed.dat` (the database,
rewritten every five minutes) and `dnsseed.dump` (a readable table of
every address with its availability windows, height, service flags and
user agent). Run it from a directory the service user can write to.

A systemd unit is provided in `contrib/veil-seeder.service`. Install it
with the paths adjusted for your host:

$ sudo cp contrib/veil-seeder.service /etc/systemd/system/
$ sudo systemctl enable --now veil-seeder

Once the seeder is serving answers, add its hostname to `vSeeds` in
`src/chainparams.cpp` so nodes actually query it.
