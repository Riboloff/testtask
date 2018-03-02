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
            ['4', 'diff4', 'hex4'],
            ['3', 'diff3', 'hex3'],
            ['2', 'diff2', 'hex2'],
            ['1', 'diff1', 'hex1'],
        ];
    };
    *test_func = \&Server::get_diff;

    is_deeply(
        test_func(
            undef,
            {version => '4'}
        ),
        {
            status => 'ok',
            data => []
        }
    );

    is_deeply(
        test_func(
            undef,
            {version => '2'}
        ),
        {
            status => 'ok',
            data => [
                ['3', 'diff3', 'hex3'],
                ['4', 'diff4', 'hex4']
            ]
        }
    );
    is_deeply(
        test_func(
            undef,
            {version => '1'}
        ),
        {
            status => 'ok',
            data => [
                ['2', 'diff2', 'hex2'],
                ['3', 'diff3', 'hex3'],
                ['4', 'diff4', 'hex4']
            ]
        }
    );
    is_deeply(
        test_func(
            undef,
            {version => '0'}
        ),
        {
            status => 'error',
            'action' => 'get_all_file'
        }
    );
}


sub test_get_version : Test(3) {
    my $self = shift;

    no warnings "redefine";
    *Server::get_tarantool_all_data = sub {
        return [
            ['4', 'diff4', 'hex4'],
            ['3', 'diff3', 'hex3'],
            ['2', 'diff2', 'hex2'],
            ['1', 'diff1', 'hex1'],
        ];
    };
    *test_func = \&Server::get_version;

    is_deeply(
        test_func(
            undef,
            {hex => 'hex4'},
        ),
        {
            status => 'ok',
            version => 4,
            hex => 'hex4'
        }
    );
    is_deeply(
        test_func(
            undef,
            {hex => 'hex1'},
        ),
        {
            status => 'ok',
            version => 1,
            hex => 'hex1'
        }
    );
    is_deeply(
        test_func(
            undef,
            {hex => 'hex0'},
        ),
        {
            status => 'error',
            action => 'get_all_file',
        }
    );
}

sub test_delete_old_client_info : Test(2) {
    my $self = shift;

    no warnings "redefine";
    *test_func = \&Server::delete_old_client_info;

    my $time = time();
    is_deeply(
        test_func(
            Tarantool->new(),
            [
                [1, $time - 20, '/diff'],
                [2, $time - 5, '/add' ],
                [3, $time, '/file'],
            ]
        ),
        [
            [2, $time - 5, '/add' ],
            [3, $time, '/file'],
        ]
    );
    is_deeply(
        test_func(
            Tarantool->new(),
            [
                [1, $time, '/diff'],
                [2, $time, '/add' ],
                [3, $time, '/file'],
            ]
        ),
        [
            [1, $time, '/diff'],
            [2, $time, '/add' ],
            [3, $time, '/file'],
        ]
    );
}



{
    package Tarantool;
    
    sub new {
        my $class = shift;
        return bless{{}, $class};
    }

    sub call_lua {
        my $self = shift;
        return;
    }
}
