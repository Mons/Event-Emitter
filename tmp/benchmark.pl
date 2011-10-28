#!/usr/bin/env perl

use lib::abs '..';
use Object::Event;
use Event::Emitter;

package OE;
use base 'Object::Event';

package EE;

use Event::Emitter;

package main;

use Benchmark ':all';

my $oe = bless {}, 'OE';
my $ee = bless {}, 'EE';

$oe->reg_cb(event => sub { $a + $b });
$oe->reg_cb(event => sub { $a + $b });
$oe->reg_cb(event => sub { $a + $b });
$oe->reg_cb(another => sub { $a + $b });

$ee->on(event => sub { $a + $b });
$ee->on(event => sub { $a + $b });
$ee->on(event => sub { $a + $b });
$ee->on(another => sub { $a + $b });

cmpthese timethese -1, {
	'OE' => sub { $oe->event('event'); $oe->event('another') },
	'EE' => sub { $ee->event('event'); $ee->event('another') },
};
