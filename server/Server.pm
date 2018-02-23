package Server;

use strict;
use warnings;
use utf8;

use lib '/home/makcimgovorov/perl5/lib/perl5/';
use Digest::MD5;
use MIME::Base64;

sub get_last_version {
    my $tarantool = shift;
    my $file_version = get_tarantool_all_data($tarantool);
    
    print Data::Dumper::Dumper($file_version);
    return $file_version->[0][0];
}

sub get_tarantool_all_data {
    my $tarantool = shift;

    my $t = $tarantool->call_lua('box.space.file:select', [], 'file');
    print Data::Dumper::Dumper($t);
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
    $tarantool->insert(
        'file', [
            undef,
            MIME::Base64::encode_base64($text),
        ]
    );

    return;
}

sub get_diff {
    my $tarantool = shift;
    my $ver_number_client = shift;

    my $file_version = get_tarantool_all_data($tarantool);

    my $diff = [];
    my $last_element = $#$file_version;
    if ($file_version->[0][0] eq $ver_number_client) {
        #Клиент на послдней версии файла
        return {'status' => 'ok', data => []};   
    }
    for (my $i = 0; $i < @$file_version; $i++) {
        if ($file_version->[$i][0] eq $ver_number_client) {
            $diff = [@$file_version[0 .. $i-1]];
            last;
        }
    }
    unless (@$diff) {
        #У клиента фигня кака-то с файлом. Пусть заново перезапросит весь файл
        return {status => 'error', 'action' => 'get_all_file'};
    }

    return {status => 'ok', data => [reverse @$diff]};
}

sub add_in_end_file {
    my $text_client = shift;

    open(my $OUTF, '>>', 'file');

    print $OUTF "$text_client";
    close($OUTF);

    return;
}

1;
