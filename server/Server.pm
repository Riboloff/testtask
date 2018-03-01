package Server;

use strict;
use warnings;
use utf8;

use lib '/home/makcimgovorov/perl5/lib/perl5/';
use Digest::MD5;
use MIME::Base64;
use Data::Dumper;

sub get_last_version {
    my $tarantool = shift;
    my $file_version = get_tarantool_all_data($tarantool);

    return {
       version => $file_version->[0][0],
       hex     => $file_version->[0][2],
    };
}

sub get_tarantool_all_data {
    my $tarantool = shift;

    my $t = $tarantool->call_lua('box.space.file:select', [], 'file');
    my $iter = $t->iter;

    my $all_data = [];
    while (my $item = $iter->next) {
        push(@$all_data, $item->raw());
    }
    return [sort{$b->[0] <=> $a->[0]} @$all_data];
}

sub init {
    my $tarantool = shift;

    my $text = '';

    open(my $INF, '<', 'file');
    while (<$INF>) {
        $text .= $_;
    }
    close($INF);

    $tarantool->call_lua('box.space.file:truncate', [], 'file');
    $tarantool->call_lua('box.space.clients:truncate', [], 'clients');
    $tarantool->insert(
        'file', [
            undef,
            MIME::Base64::encode_base64($text),
            (split(' ', `md5sum ./file`))[0],
        ]
    );

    return;
}

sub get_diff {
    my $tarantool = shift;
    my $req_params = shift;

    my $version_client = $req_params->{'version'};

    my $col_num = 0;

    my $file_version = get_tarantool_all_data($tarantool);

    my $diff = [];
    my $last_element = $#$file_version;
    if ($file_version->[0][0] eq $version_client) {
        #Клиент на послдней версии файла
        return {'status' => 'ok', data => [], 'hex' => $file_version->[0][2], 'version' => $file_version->[0][0]};
    }
    for (my $i = 0; $i < @$file_version; $i++) {
        if ($file_version->[$i][0] eq $version_client) {
            $diff = [@$file_version[0 .. $i-1]];
            last;
        }
    }
    unless (@$diff) {
        #У клиента фигня кака-то с файлом. Пусть заново перезапросит весь файл
        return {status => 'error', 'action' => 'get_all_file'};
    }

    return {
        status => 'ok',
        data => [reverse @$diff],
    };
}

sub get_version {
    my $tarantool = shift;
    my $req_params = shift;

    my $hex_file_client = $req_params->{'hex'};

    my $file_version = get_tarantool_all_data($tarantool);

    for my $v (@$file_version) {
        my $hex = $v->[2];
        my $version = $v->[0];
        if ($hex eq $hex_file_client) {
            return {
                status => 'ok',
                version => $version,
                hex => $hex,
            };
        }
    }
        print Dumper($file_version);
    return {status => 'error', 'action' => 'get_all_file'};
}

#TODO: flock
#Tie::File;
#use Fcntl;
#tie @data. Tie::File. $FILENAME or die "Can't tie to Sfilename : $!\n";
sub add_in_end_file {
    my $text_client = shift;

    open(my $OUTF, '>>', 'file');

    print $OUTF "$text_client";
    close($OUTF);

    my ($hex) = split(' ', `md5sum ./file`);
    return $hex;
}

sub get_clientid {
    my $tarantool = shift;

    my $res = $tarantool->insert(
        'clients', [
            undef,
            time,
        ]
    );
    print Dumper($res->raw(0));
    return $res->raw(0);
}

sub create_clientid {
    my $tarantool = shift;

    my $res = $tarantool->insert(
        'clients', [
            undef,
            time,
        ]
    );
    print Dumper($res->raw(0));
    return $res->raw(0);
}

sub create_connect {
    my $tarantool = shift;

    return {
        clientid => create_clientid($tarantool),
        %{get_last_version($tarantool)},
    };
}

sub logging_client {
    my $tarantool = shift;
    my $clientid = shift;
    my $path = shift;

    print "clientid = $clientid\n";
    print "path = $path\n";

    my $t = $tarantool->replace(
        'clients', [
            int $clientid,
            time(),
            $path,
        ]
    );
}

sub get_admin_info {
    my $tarantool = shift;

    my $t = $tarantool->call_lua('box.space.clients:select', [], 'clients');
    my $iter = $t->iter;

    my $all_data = [];
    while (my $item = $iter->next) {
        push(@$all_data, $item->raw());
    }
    return $all_data;
}

1;
