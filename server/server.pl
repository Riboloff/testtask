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
            {name => 'inc', type => 'NUM'},
            {name => 'diff', type => 'UTF8STR'},
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
            if ($path eq '/file') {
                my %args = (
                    headers => {
                        LastVersion => Server::get_last_version($tarantool),
                    },
                );
                $request->sendfile(200, FILE, %args);
                return;
            }
            elsif ($path eq '/diff') {
                my $version_client = $request->params()->{'version'};
                $content = JSON::XS::encode_json(Server::get_diff($tarantool, $version_client));
            }
            elsif ($path eq '/add') {
                my $text_client = MIME::Base64::decode_base64($request->params()->{'text'});

                Server::add_in_end_file($text_client);
                #$file_content .= $text_client;
                #my $hex = Digest::MD5::md5_hex($file_content);

                #push(@$file_version, {
                #        hex  => $hex,
                #        diff => $text_client,
                #    }
                #);
                my $insert_data = $tarantool->insert(
                    'file', [
                        undef,
                        MIME::Base64::encode_base64($text_client),
                    ]
                );
                #my $new_version = $insert_data->iter->raw(0);
                #$content = JSON::XS::encode_json({version => $new_version});
                $content = '';
            }
            $request->reply($status, $content, headers => $headers);
        }
);
$s->listen;

for (1 .. CHILDREN) {
   my $pid = fork();
   die "fork error: $!" unless defined $pid;
}

$s->accept;
my $sig = AE::signal INT => sub {
        warn "Stopping server";
        $s->graceful(sub {
            warn "Server stopped";
            EV::unloop();
        });
};

EV::loop();
