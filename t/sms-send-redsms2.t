use strict;
use warnings;

use Test::More tests => 6;

use_ok('SMS::Send::RedSMS2');

subtest 'new() tests' => sub {
        plan tests => 4;

        ok(SMS::Send::RedSMS2->can('new'), 'method new() available');

        my $driver = SMS::Send::RedSMS2->new(
            _login    => 'test',
            _api => 'test',
            _sender => 'test'
        );

        is(ref($driver), 'SMS::Send::RedSMS2', 'new() returns an instance of SMS::Send::RedSMS2');

        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _sender    => 'test',
                _api => 'test'
            );
        };

        like($@, qr/required/, 'Login required');

        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _login    => 'test',
                _sender => 'test'
            );
        };

        like($@, qr/required/, 'Api required');
    };

subtest 'send_sms() tests' => sub {
        plan tests => 3;

        ok(SMS::Send::RedSMS2->can('send_sms'), 'method send_sms() available');

        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _login    => 'test',
                _api => 'test',
                _from   => 'test'
            )->send_sms( to => 1 );
        };
        like($@, qr/to and text are required/, 'Missing parameters');

        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _login    => 'test',
                _api => 'test',
                _from   => 'test'
            )->send_sms( text => 1 );
        };
        like($@, qr/to and text are required/, 'Missing parameters');

    };

can_ok('SMS::Send::RedSMS2' ,'balance');

subtest 'status() tests' => sub {
        plan tests => 2;

        ok(SMS::Send::RedSMS2->can('status'), 'method status() available');

        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _login    => 'test',
                _api => 'test'
            )->status();
        };
        like($@, qr/At least one sms-id \(uuid\) is required/, 'Missing parameters');
    };
	

subtest 'info() tests' => sub {
        plan tests => 3;

        ok(SMS::Send::RedSMS2->can('info'), 'method info() available');

        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _login    => 'test',
                _api => 'test'
            )->info();
        };
        like($@, qr/You must set at least one required filter parameter/, 'Missing parameters');


        eval {
            my $driver = SMS::Send::RedSMS2->new(
                _login    => 'test',
                _api => 'test'
            )->info(test=>'test');
        };
        like($@, qr/Unknown filter: test/, 'Wrong filter checking');		
    };	