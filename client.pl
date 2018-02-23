#! /usr/bin/perl

use strict;
use warnings;
use utf8;
use lib '/home/makcimgovorov/perl5/lib/perl5/';
use AnyEvent::UA;
use LWP::UserAgent;
use MIME::Base64;
use Digest::MD5;
use Time::HiRes qw/usleep/;
use JSON::XS;

use Data::Dumper;

use constant {
    FILE => 'file',
    BASE_URL => 'http://127.0.0.1:8080',
};

my $N = $ARGV[0];

my $ua = LWP::UserAgent->new();

$ua->timeout(1);

my $file_content_server = {};

get_all_file();

print Dumper($file_content_server);

my $count_tmp = 0;

while(1) {
    if ($count_tmp == 3 or $count_tmp == 7) {
        add_str("1111111111111=$N\n");
    }
    elsif ($count_tmp == 5 or $count_tmp == 10) {
        add_str("22222222222=$N\n");
    }
    get_diff($file_content_server->{version});
    usleep(2_000_000);
    if($count_tmp++ > 15) {
        print Dumper($file_content_server);
        last;
    }
    #_print();
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
    my $version = shift;
    
    my $response = $ua->get(BASE_URL . '/diff' . "?version=$version");

    if ($response->is_success) {
        my $res = JSON::XS::decode_json($response->decoded_content); 


        my $status = $res->{status} // 'error';
        my $data = $res->{data} // [];
        if ($status eq 'ok') {
            if (@$data) {
                for my $change (@$data) {
                    my $text = MIME::Base64::decode_base64($change->[1]);
                    $file_content_server->{text} .= $text;
                }
                $file_content_server->{version} = $data->[-1][0];
            }
            else {
                print "Theare aren't new strings\n";
            }
        }
        elsif ($status eq 'error') {
           if ($res->{action} eq 'get_all_file') {
                get_all_file();
           } 
        }
    }
}

sub get_all_file {
    my $response = $ua->get(BASE_URL . '/file');

    if ($response->is_success) {
        my $file = $response->decoded_content; 

        $file_content_server = {
            version  => $response->header('lastversion'),
            text => $file,
        };
    }
}


sub _print {
    my ($wchar, $hchar) = GetTerminalSize();

}
