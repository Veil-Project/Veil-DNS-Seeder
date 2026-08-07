veil-seeder
==============

Veil-seeder is a crawler for the Veil network, which exposes a list
of reliable nodes via a built-in DNS server.

Features:
* regularly revisits known nodes to check their availability
* bans nodes after enough failures, or bad behaviour
* keeps statistics over (exponential) windows of 2 hours, 8 hours,
  1 day and 1 week, to base decisions on.
* very low memory (a few tens of megabytes) and cpu requirements.
* crawlers run in parallel (by default 96 threads simultaneously).

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


DEPLOYING
---------

The host needs a public IP, UDP 53 reachable, and an NS delegation
pointing the seed hostname at it. With the delegation in place:

$ ./dnsseed -h dnsseed.veil-project.com -n vps.veil-project.com -m admin.veil-project.com -t 16

`-t 96` is sized for a network with thousands of nodes; on Veil's
current network 16 threads is plenty.

Give it a few minutes, then check that it answers:

$ dig +short @localhost -p 5353 dnsseed.veil-project.com

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
