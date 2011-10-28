#!/usr/bin/env perl
use Test::More tests => 16 + eval { require Test::NoWarnings;Test::NoWarnings->import; 1 };;
use lib::abs '../lib';

package foo;
use Event::Emitter -base;
sub new { bless {},shift}
package main;

=for rem
sub say (@) { print "@_\n" }

my $c = Event::Emitter::EC->new;

$c->head(my $h1 = sub { say "head 1" });
$c->tail(my $t2 = sub { say "tail 1" });
$c->head(my $h2 = sub { say "head 2" });
$c->tail(my $t2 = sub { say "tail 2" });

$c->tail(-1000 => my $tk = sub { say "tail -k" });
$c->head(+1000 => my $hk = sub { say "head +k" });

for my $cb ( @{ $c->linear }) {
	$cb->();
}

say "";
$c->del($h2);

for my $cb ( @{ $c->linear }) {
	$cb->();
}

__END__
=cut

my $f = foo->new;

my $order = 0;
my $not_called = 1;

$f->on(sample => sub { $not_called = 0; });
$f->on(sample => sub { my $s = shift; is ++$order, 2, 'filo 2';  is $_[0], 'arg', 'argument 2'; $s->handled; });
$f->on(sample => sub { shift; is ++$order, 1, 'filo 1'; is $_[0], 'arg', 'argument 1' });
$f->event('sample','arg');
ok $not_called, 'event after stop not called';

$f->on(sample => sub { $not_called = 0; });
$f->no('sample');
$f->event('sample','arg');
ok $not_called, 'event after unreg not called';

my $died = 0;
$f->on(__DIE__ => sub { $died++ });
$f->on(__DIE__ => sub { $died++ });
$f->on(sample => sub { die });
$f->on(sample => sub { die });
$f->on(sample => sub { ok 1, 'before die' });
$f->event('sample','arg');
is $died,2, 'died handled ok';

$f->no('sample');

my $once = 0;
$f->once('sample' => sub { $once++ });
$f->event('sample','arg');
$f->event('sample','arg');
is $once, 1, 'once called once';
#$f->on(__DIE__ => sub { die });
#$f->on(__DIE__ => sub { $died++ });
#$f->on(sample => sub { die });
#$f->event('sample','arg');

$f->no('sample');

my $count = 0;
$f->on('sample', my $s1 = sub { ++$count; });
$f->event('sample');
is $count,1, 'enable/disable: first event';
$f->on('sample', my $s2 = sub { ++$count; });
$f->event('sample');
is $count,3, 'enable/disable: 2nd event';
$f->on('sample', my $s3 = sub { ++$count; });
$f->on('sample', $s1);
$f->event('sample');
is $count,7, 'enable/disable: 3rd event + dup';
$f->no($s3);
$f->event('sample');
is $count,10, 'enable/disable: remove one event';
$f->no($s1);
$f->event('sample');
is $count,11, 'enable/disable: remove dup event';
$f->no('sample');
$f->event('sample');
is $count,11, 'enable/disable: removed all';

$f->on('sample', $s1);
$f->on('another', $s1);
$f->no();
$f->event('sample');
$f->event('another');
is $count,11, 'no without arguments remove all';
exit;
require Test::NoWarnings;
