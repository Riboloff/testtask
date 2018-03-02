#! /usr/bin/perl

use strict;
use warnings;
use utf8;
use lib '/home/makcimgovorov/perl5/lib/perl5/';
use AnyEvent::UA;
use LWP::UserAgent;
use MIME::Base64;
use Time::HiRes qw/usleep/;
use JSON::XS;
use Tie::File;
use Term::ANSIScreen;
use Term::ReadKey;

use Data::Dumper;

use constant {
    FILE => 'file',
    BASE_URL => 'http://127.0.0.1:8080',
    ENTER_KEY => 10,
};

my $N = $ARGV[0] // 0;
my $path_to_file = './data/' . $N;

my $input_line = "";
$SIG{INT} = sub {ReadMode('normal'); clear_console(); exit(0)};

my $ua = LWP::UserAgent->new();
$ua->timeout(1);

$| = 1;
my ($wchar, $hchar) = GetTerminalSize();
my $console = Term::ANSIScreen->new;
if ($N eq 'admin') {
    admin_mode_loop();
}

my $file_content_server = {};

init();
main_loop();

sub init {
    my $url = BASE_URL . '/connect';
    my $response = http_get($url);
    my $res = JSON::XS::decode_json($response->decoded_content);
    my ($clientid, $last_version, $hex_server) = @$res{qw(clientid version hex)};

    my $file = $path_to_file . '/' . FILE;
    if (-e $file) {
        my ($hex_client) = split(' ', `md5sum ./$file`);
        if ($hex_client eq $hex_server) {
            tie_file_array(
                $file,
                $last_version,
                $clientid,
                $hex_client,
            );
        }
        else {
            my $cur_version = get_version($hex_client, $clientid);
            if ($cur_version) {
                tie_file_array(
                    $file,
                    $cur_version,
                    $clientid,
                    $hex_client,
                );
            }
            else {
                get_all_file($clientid);
            }
        }
    }
    else {
        `mkdir $path_to_file`;
        `touch $file`;
        get_all_file($clientid);
    }

    return;
}

sub main_loop {
    my $count_tmp = 0;
    while(1) {
        get_diff();
        _print(join("\n", @{$file_content_server->{text_array}}));
        usleep(200_000);
    }
}

sub add_str {
    my $str = shift;

    my $base64 = MIME::Base64::encode_base64($str);
    my $clientid = $file_content_server->{clientid};

    my $url = BASE_URL . '/add' . "?text=$base64&clientid=$clientid";
    my $response = http_get($url);
}

sub get_diff {
    my ($version, $clientid) = @$file_content_server{qw(version clientid)};
    my @get_params = (
        "version=$version",
        "clientid=$clientid",
    );

    my $url = BASE_URL . '/diff' . '?'. join('&', @get_params);
    my $response = http_get($url);
    my $res = JSON::XS::decode_json($response->decoded_content);
    my $status = $res->{status} // 'error';
    my $data = $res->{data} // [];
    if ($status eq 'ok') {
        if (@$data) {
            for my $change (@$data) {
                my $text = MIME::Base64::decode_base64($change->[1]);
                #$file_content_server->{text} .= $text;
                push(@{$file_content_server->{text_array}}, split(/\n/, $text) );
            }
            $file_content_server->{version} = $data->[-1][0];
        }
    }
    elsif ($status eq 'error') {
       if ($res->{action} eq 'get_all_file') {
            get_all_file($clientid);
       }
    }
}

sub get_version {
    my $hex = shift;
    my $clientid = shift;

    my @get_params = (
        "hex=$hex",
        "clientid=$clientid",
    );

    my $url = BASE_URL . '/version' . '?' . join('&', @get_params);
    my $response = http_get($url);
    my $res = JSON::XS::decode_json($response->decoded_content);

    if ($res->{status} eq 'ok') {
        my $version = $res->{version};
        return $version;
    }
    elsif ($res->{status} eq 'error') {
        return;
    }
}

sub get_all_file {
    my $clientid = shift;

    my $url = BASE_URL . '/' . FILE . '?' . "clientid=$clientid";
    my $response = http_get($url);
    my $all_text = $response->decoded_content;

    tie_file_array(
        $path_to_file . '/' . FILE,
        $response->header('version'),
        $clientid,
        $response->header('hex'),
        $all_text,
    );
}

sub tie_file_array {
    my ($file, $version, $clientid, $hex, $text) = @_;

    my @text_array = ();
    tie(@text_array, "Tie::File", "$file") or die('Canot open file');

    if ($text) {
        @text_array = split(/\n/, $text);
    } else {
        $text = join("\n", @text_array);
    }
    $file_content_server = {
        version  => $version,
        text => $text,
        text_array => \@text_array,
        clientid => $clientid,
        hex => $hex,
    };
}


sub admin_mode_loop {
	clear_console();

    while(1) {
        _print(admin_connect());

        usleep(500_000);
    }
}

sub clear_console {
    $console->Cursor(0, 0);
	for (my $y = 0; $y < $hchar - 1; $y++) {
		print " " x $wchar;
	}
}

sub admin_connect {
    my $response = $ua->get(BASE_URL . '/admin');

    return unless ($response->is_success);

    my $res = JSON::XS::decode_json($response->decoded_content);

    return $res;
}

sub _print {
    my $data = shift;

	clear_console();
    $console->Cursor(0, 0);

    print Dumper($data);
    if ($N eq 'admin') {
        return;
    }
    ReadMode ('cbreak');
    if (defined (my $char = ReadKey(-1) )) {
        if (ord $char eq ENTER_KEY) {
            add_str($input_line . "\n");
            $input_line = "";
            $console->Cursor(0, $hchar);
            print " " x $wchar;
        } else {
            $console->Cursor(0, $hchar);
            $input_line .= $char;
            print $input_line;
        }
    }
}

sub http_get {
    my $url = shift;

    my $response;
    while (1) { #бесконечне ретраи
        $response = $ua->get($url);
        last if ($response->is_success);
    }

    return $response;
}
