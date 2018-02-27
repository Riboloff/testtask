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

use Data::Dumper;

use constant {
    FILE => 'file',
    BASE_URL => 'http://127.0.0.1:8080',
};

my $N = $ARGV[0] // 0;

my $path_to_file = './data/' . $N;

my $ua = LWP::UserAgent->new();

$ua->timeout(1);

my $file_content_server = {};

init();

print Dumper($file_content_server);
my $count_tmp = 0;

while(1) {
    if ($N != 2 and ($count_tmp == 3 or $count_tmp == 7)) {
        add_str("1111111111111=$N\n");
    }
    elsif ($N != 2 and ($count_tmp == 5 or $count_tmp == 10)) {
        add_str("22222222222=$N\n");
    }
    get_diff("version=$file_content_server->{version}");
    usleep(2_000_000);
    if($count_tmp++ > 15) {
        print Dumper($file_content_server);
        last;
    }
    #_print();
}

sub init {
    my $file = $path_to_file . '/' . FILE;
    #TODO тут совсем не красиво!!!
    unless ( open(my $INF, '<', "./$file")) {
        `touch $file`;
        get_all_file();
        return;
    }
    my ($hex) = split(' ', `md5sum ./$file`);
    my @text_array = ();
    tie(@text_array, "Tie::File", "$file") or die('Canot open file');
    $file_content_server = {
        version  => get_version($hex),
        text => join("\n", @text_array),
        text_array => \@text_array,
    };

}

sub add_str {
    my $str = shift;

    my $base64 = MIME::Base64::encode_base64($str);

    my $response = $ua->get(BASE_URL . '/add' . "?text=$base64");

    if ($response->is_success) {
        print "String $str sended.\n";
    }
}

sub get_diff {
    print "get_diff\n";
    my $get_params = shift;
    
    my $response = $ua->get(BASE_URL . '/diff' . "?$get_params");

    if ($response->is_success) {
        my $res = JSON::XS::decode_json($response->decoded_content); 
        my $status = $res->{status} // 'error';
        my $data = $res->{data} // [];
        if ($status eq 'ok') {
            if (@$data) {
                for my $change (@$data) {
                    my $text = MIME::Base64::decode_base64($change->[1]);
                    $file_content_server->{text} .= $text;
                    push(@{$file_content_server->{text_array}}, split(/\n/, $text) );
                }
                $file_content_server->{version} = $data->[-1][0];
            }
            else {

                print "Theare aren't new strings\n";
            }
        }
        elsif ($status eq 'error') {
           if ($res->{action} eq 'get_all_file') {
                print "error, need get_all_file\n";
                get_all_file();
           }
        }
    }
}

sub get_version {
    print "get_version\n";
    my $hex = shift;

    my $response = $ua->get(BASE_URL . '/version' . "?hex=$hex");

    if ($response->is_success) {
        my $res = JSON::XS::decode_json($response->decoded_content); 
        if ($res->{status} eq 'ok') {
            my $version = $res->{version};
            return $version;
        }
        elsif ($res->{status} eq 'error') {
           if ($res->{action} eq 'get_all_file') {
                get_all_file();
           }
        }
    }
}

sub get_all_file {
    my $response = $ua->get(BASE_URL . '/file');

    if ($response->is_success) {
        my $all_text = $response->decoded_content; 

        my @text_array = ();
        tie(@text_array, "Tie::File", $path_to_file . '/' . FILE) or die('Canot open file');
        @text_array = split(/\n/, $all_text);

        $file_content_server = {
            version  => $response->header('lastversion'),
            text => $all_text,
            text_array => \@text_array,
        };
    }
}

sub _print {
    my ($wchar, $hchar) = GetTerminalSize();

}
