#!/usr/bin/env perl -w

use common::sense;
use lib::abs '../lib';
use Test::More tests => 2;
use Test::NoWarnings;

BEGIN {
	use_ok( 'Event::Emitter' );
}

diag( "Testing Event::Emitter $Event::Emitter::VERSION, Perl $], $^X" );
exit;
require Test::NoWarnings;
