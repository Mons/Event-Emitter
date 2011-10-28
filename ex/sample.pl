#!/usr/bin/env perl

use 5.010;
use lib::abs '../lib';
package X;

use Event::Emitter;

sub new { return bless {},shift }

package main;

my $x = X->new;

$x->on(sample => sub {
	say "catched sample 1 (@_)";
});
$x->on(sample => sub {
	say "catched sample 2 (@_)";
	$x->handled;
});
$x->on(sample => sub {
	say "catched sample 3 (@_)";
});
$x->event('sample', "xxx");

say $x->handles('sample');
say $x->handles('nosample');
