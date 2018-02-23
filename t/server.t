#! /usr/bin/perl 

use strict;
use warnings;

use lib::abs qw(../server);
use Test::Most;
use base qw(Test::Class);
use Data::Dumper;

use Server;
Test::Class->runtests;

sub setup : Test(setup) {

}


sub test_get_diff : Test(4) {
    my $self = shift;

    no warnings "redefine";
    *Server::get_tarantool_all_data = sub {
        return [
            ['4', 'diff4'],
            ['3', 'diff3'],
            ['2', 'diff2'],
            ['1', 'diff1'],
        ];
    };
    *test_func = \&Server::get_diff;
    is_deeply(test_func('4'), {status => 'ok', data => []});
    is_deeply(test_func('2'), {status => 'ok', data => [['3', 'diff3'], ['4', 'diff4']]});
    is_deeply(test_func('1'), {status => 'ok', data => [['2', 'diff2'], ['3', 'diff3'], ['4', 'diff4']]});
    is_deeply(test_func('0'), {status => 'error',  'action' => 'get_all_file'});
}
