#! /usr/bin/perl

use strict;
use warnings;

use utf8;

use lib '/home/makcimgovorov/perl5/lib/perl5/';
use AnyEvent::HTTP::Server;
use Data::Dumper;
use Digest::MD5;
use MIME::Base64;

use constant {
    FILE => 'file',
    #CHILDREN => 2,
};

our $file_version = [];
our $file_content = '';

init();
my $s = AnyEvent::HTTP::Server->new(
        host => '127.0.0.1',
        port => 8080,
        cb => sub {
            my $request = shift;
            my $path = $request->path();
            my $status  = 200;
            my $content = "<h1>Reply message</h1>";
            my $headers = { 'content-type' => 'text/html' };
            if ($path eq '/file') {
                $request->sendfile(200, FILE);
                return;
            }
            elsif ($path eq '/diff') {
                my $hex_client = $request->params()->{'hex'};
                my $last_hex = $file_version->[$#$file_version]->{hex};
                if ($hex_client eq $last_hex) {
                    $content = '';
                }
                else {
                    $content = get_diff($hex_client);
                }
            }
            elsif ($path eq '/add') {
                my $text_client = MIME::Base64::decode_base64($request->params()->{'text'});

                add_in_end_file($text_client);
                $file_content .= $text_client;
                my $hex = Digest::MD5::md5_hex($file_content);

                push(@$file_version, {
                        hex  => $hex,
                        diff => $text_client,
                    }
                );
                $content = '';
            }
            $request->reply($status, $content, headers => $headers);
        }
);
$s->listen;

#for (1 .. CHILDREN) {
#   my $pid = fork();
#    die "fork error: $!" unless defined $pid;
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


sub init {
    open(my $INF, '<', 'file');

    my $text = '';
    while (<$INF>) {
        $text .= $_;
    }
    $file_content = $text;
    $file_version->[0] = {
        hex => Digest::MD5::md5_hex($text),
        diff => $text,
    };
    close($INF);

    return;
}

sub get_diff {
    my $hex_client = shift;

    my $diff = [];
    for my $version (reverse @$file_version) {
        if ($version->{hex} ne $hex_client) {
            push(@$diff, $version->{diff});
        }
        else {
            last;
        }
    }

    return join("", reverse @$diff);
}

sub add_in_end_file {
    my $text_client = shift;

    open(my $OUTF, '>>', 'file');

    print $OUTF "$text_client";
    close($OUTF);

    return;
}
