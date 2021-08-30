#!perl -T
use Modern::Perl;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'SMS::Send::Telia::Driver' ) || print "Bail out!\n";
}

diag( "Testing SMS::Send::Telia::Driver $SMS::Send::Telia::Driver::VERSION, Perl $], $^X" );