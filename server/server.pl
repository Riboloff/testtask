#! /usr/bin/perl

use strict;
use warnings;

use lib '/home/makcimgovorov/perl5/lib/perl5/';
use Server;
use AnyEvent::HTTP::Server;
use Data::Dumper;
use JSON::XS;

use DR::Tarantool ':constant', 'tarantool';
use DR::Tarantool ':all';
use DR::Tarantool::MsgPack::SyncClient;
use DR::Tarantool::Spaces;

use constant {
    FILE => 'file',
    CHILDREN => 2,
};
my $spaces = new DR::Tarantool::Spaces({
    24 => {
        name => 'file',
        default_type    => 'STR',
        user    => 'guest',
        fields => [
            {name => 'inc',  type => 'NUM'},
            {name => 'diff', type => 'UTF8STR'},
            {name => 'hex',  type => 'STR'},
        ],
        indexes => {}
    },
    25 => {
        name => 'clients',
        default_type    => 'STR',
        user    => 'guest',
        fields => [
            {name => 'id', type => 'NUM'},
            {name => 'time', type => 'NUM'},
            {name => 'version', type => 'NUM'},
            {name => 'comand', type => 'STR'},
        ],
        indexes => {}
    }
});

my $tarantool = DR::Tarantool::MsgPack::SyncClient->connect(
    host    => '127.0.0.1',
    port    => 3324,
    user    => 'guest',
    spaces  => $spaces,
);

Server::init($tarantool);

my $s = AnyEvent::HTTP::Server->new(
        host => '127.0.0.1',
        port => 8080,
        cb => sub {
            my $request = shift;
            my $path = $request->path();
            my $status  = 200;
            my $content = '';
            my $headers = { 'content-type' => 'text/json' };
            print Dumper($path, $request->params);
            if ($path eq '/admin') {
                $content = JSON::XS::encode_json(Server::get_admin_info($tarantool));
                $request->reply($status, $content, headers => $headers);
                return;
            }
            my $clientid = $request->params()->{'clientid'};
            if ($path eq '/connect') {
                $content = JSON::XS::encode_json(Server::create_connect($tarantool));
                $request->reply($status, $content, headers => $headers);
                return;
            }
            Server::logging_client($tarantool, $clientid, $path);
            if ($path eq '/file') {
                my %args = (
                    headers => {
                        %{ Server::get_last_version($tarantool) },
                    },
                );
                $request->sendfile(200, FILE, %args);
                return;
            }
            elsif ($path eq '/version') {
                $content = JSON::XS::encode_json(Server::get_version($tarantool, $request->params()));
            }
            elsif ($path eq '/diff') {
                $content = JSON::XS::encode_json(Server::get_diff($tarantool, $request->params()));
            }
            elsif ($path eq '/add') {
                my $text_client = MIME::Base64::decode_base64($request->params()->{'text'});

                my $hex = Server::add_in_end_file($text_client);

                my $insert_data = $tarantool->insert(
                    'file', [
                        undef,
                        MIME::Base64::encode_base64($text_client),
                        $hex,
                    ]
                );
                $content = '';
            }
            print Dumper($content);
            $request->reply($status, $content, headers => $headers);
        }
);
$s->listen;

#for (1 .. CHILDREN) {
#   my $pid = fork();
#   die "fork error: $!" unless defined $pid;
#}

$s->accept;
my $sig = AE::signal INT => sub {
        warn "Stopping server";
        $s->graceful(sub {
            warn "Server stopped";
            EV::unloop();
        });
};

EV::loop();
