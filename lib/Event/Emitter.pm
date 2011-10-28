package Event::Emitter;

use 5.008008;
use common::sense 2;m{
use strict;
use warnings;
};
use Carp;

=head1 NAME

Event::Emitter - Glue for event-driven programming, inside out

=cut

our $VERSION = '0.01'; $VERSION = eval($VERSION);

=head1 SYNOPSIS

    package Sample;
    use Event::Emitter;

    sub new { ... }
    
    package main;
    
    my $o = Sample->new;
    $o->on(
        event => sub { ... }
    );
    
    $o->event(event => @args);
    
    $o->no('event');
    

=head1 DESCRIPTION

This module is something between L<Object::Event> and Node.js' EventEmitter.
    
The differences from L<Object::Event> are:

=over 4

=item L<Event::Emitter> not affects object structure or content. All things about events stored outside object

=item L<Event::Emitter> uses interface similar to Node.js' EventEmitter (for ex C<on()> instead of C<reg_cb()> )

=item L<Event::Emitter> uses opposite order when calling events, registered under same name. C<OE> uses C<FIFO>, C<EE> uses C<LIFO>

=item L<Event::Emitter> does not implement attributes.

=item L<Event::Emitter> does not set itself as a base class (could be changed with C<-base> flag).

=back

=cut

=head1 METHODS

=over 4

=item [ $guard = ] $obj->on( $event_name, [$prio], $cb )

Register one or more event handler

	$obj->on( $event_name, [$prio], $cb, [ $event_name, [$prio], $cb, ... ] );
	# or with guard
	my $guard = $obj->on( $event_name, [$prio], $cb);
	...
	undef $guard;

=item $obj->once( $event_name, [$prio], $cb)

Register event handler for single run

	$obj->once( $event_name, [$prio], $cb );
	$obj->event($event_name); # $cb called
	$obj->event($event_name); # $cb not called

=item $obj->no(...)

Unregister event

	$obj->no($cb);    # Unregister by callback
	$obj->no('name'); # Unregister all events by name
	$obj->no();       # Unregister all events

=item $obj->handles($event_name);

Return true, if event would handled by $obj

=item $obj->handled()

Stop processing current event chain.

    my $x = X->new;
    $x->on(sample => sub { say "sample 1"  });
    $x->on(sample => sub { say "sample 2"; $x->handled; });
    $x->on(sample => sub { say "sample 3"  });
    $x->event('sample');
    
    # Will output
    sample 3
    sample 2

=item $obj->event($event_name,@args);
=item $obj->emit($event_name,@args);

Emit event C<$event_name> and call every handler in chain.

=item $obj->on(__DIE__, $cb)

Set exception handler. C<__DIE__> is just a special name

=back

=head2 Compatibility with L<Object::Event>

L<Event::Emitter> implements compatibility methods with L<Object::Event>. It is enabled with C<-oecompat> flag:

    use Event::Emitter -base, -oecompat;

=over 4

=item reg_cb(...) as on(...)

=item unreg_cb(...) as no(...)

=item set_exception_cb($cb) as on(__DIE__,$cb)

=item remove_all_callbacks() as no()

=back

=cut

our %FLAGS;
sub import {
	shift;
	my $class = caller;
	for my $x (@_) {
		local $_ = $x;
		s{^-}{} or next;
		$FLAGS{$class}{$_}++;
	}
	no strict 'refs';
	if ($FLAGS{$class}{base}) {
		if ($FLAGS{$class}{oecompat}) {
			push @{ $class.'::ISA' }, 'Event::Emitter::OEBase';
		} else {
			push @{ $class.'::ISA' }, 'Event::Emitter::Base';
		}
	} else {
		*{ caller() . '::on' } = \&Event::Emitter::Core::on;
		*{ caller() . '::once' } = \&Event::Emitter::Core::once;
		*{ caller() . '::no' } = \&Event::Emitter::Core::no;
		*{ caller() . '::event' } = *{ caller() . '::emit' } = \&Event::Emitter::Core::event;
		*{ caller() . '::handles' } = \&Event::Emitter::Core::handles;
		*{ caller() . '::handled' } = \&Event::Emitter::Core::handled;
		if ($FLAGS{$class}{oecompat}) {
			*{ caller() . '::reg_cb' } = \&Event::Emitter::Core::reg_cb;
			*{ caller() . '::unreg_cb' } = \&Event::Emitter::Core::no;
			*{ caller() . '::set_exception_cb' } = \&Event::Emitter::Core::die_cb;
			*{ caller() . '::remove_all_callbacks' } = \&Event::Emitter::Core::no_all;
		}
	}
}

package #hide
	Event::Emitter::Guard;

sub new { bless $_[1],$_[0] }
sub DESTROY { shift->(); }
sub Event::Emitter::_Guard (&) { Event::Emitter::Guard->new($_[0]); }


package #hide
	Event::Emitter::Core;

use 5.008008;
use common::sense 2;m{
use strict;
use warnings;
};
use Carp;
use Scalar::Util 'refaddr';




our %HANDLERS;
our %FLOW;

our %OE_PRIO = (
	before     =>  -1000,
	ext_before =>   -500,
	ext_after  =>  500,
	after      => 1000,
);

sub reg_cb {
	my $obj = shift;
	my @args;
	while (@_) {
		my ($ev,$cb) = splice @_,0,2;
		my $prio = 0;
		if (ref $cb) {
			for my $prefix (keys %OE_PRIO) {
				if ($ev =~ s/^\Q$prefix\E_//) {
					$prio = $OE_PRIO{$prefix};
					last;
				}
			}
		} else {
			$prio = $cb; $cb = shift;
		}
		push @args, $ev,$prio,$cb;
	}
	@_ = ( $obj, @args );
	goto &on;
}

sub on {
	my $obj = shift;
	my $id = refaddr $obj;
	my ($ev,$prio,$cb);
	#warn ">> enter loop (@_)";
	my @cbs;
	while (@_) {
		if (!defined $ev) { $ev = shift; }
		elsif (UNIVERSAL::isa $_[0], 'CODE') {
			$prio = 0 unless defined $prio;
			$cb = shift;
			
			my $ec = $HANDLERS{$id}{$ev} ||= Event::Emitter::EC->new();
			#warn "add $cb to ev $ev with $prio (ec $ec)";
			$ec->add( $prio, [ $cb,undef ] );
			push @cbs, $cb;
			
			$ev = $prio = $cb = undef;
		}
		elsif ( int $_[0] eq $_[0] ) {
			$prio = shift;
		}
		elsif (defined $ev and !defined $_[0]) {
			shift;
			$obj->no($ev);
		}
		else {
			croak "Bad arguments: @_";
		}
	}
	#warn "<< leave loop";
	return
		defined wantarray ? 
		Event::Emitter::_Guard { $obj->no($_) for @cbs; }
		: ();
}

sub once {
	my $obj = shift;
	my $id = refaddr $obj;
	my ($ev,$cb) = @_;
	my $ev = shift; my $cb = pop; my $pri = shift;
	my $ec = $HANDLERS{$id}{$ev} ||= Event::Emitter::EC->new();
	$ec->add( $pri, [ $cb,1 ] );
	return
		defined wantarray ? 
		Event::Emitter::_Guard { $obj->no($cb) }
		: ();
}

sub die_cb {
				my $obj = shift;
				$obj->no('__DIE__');
				if (defined $_[0] and ref $_[0]) {
					$obj->on('__DIE__', @_);
				}
	
}

sub handles {
	my $obj = shift;
	my $id = refaddr $obj;
	my $ev = shift;
	return exists $HANDLERS{$id}{$ev} ? $HANDLERS{$id}{$ev}->count : 0;
}

sub no {
	my $obj = shift;
	my $id = refaddr $obj;
	unless (@_) {
		delete $HANDLERS{$id};
		return;
	}
	my $cb = shift;
	if (ref $cb) {
		if (UNIVERSAL::isa($cb, 'CODE')) {
			for my $ec ( values %{ $HANDLERS{$id} } ) {
				$ec->del($cb);
			}
		} else {
			die "Not implemented unreg for $cb";
		}
	} else {
		my $ev = $cb;
		delete $HANDLERS{$id}{$ev};
	}
}

sub no_all {
	my $obj = shift; $obj->no();
}

sub event {
	my $obj = shift;
	my $id = refaddr $obj;
	my $ev = shift;
	exists $HANDLERS{$id}{$ev} or return undef;
	{
		local $FLOW{$id} = $ev;
		my $ec = $HANDLERS{$id}{$ev} ||= Event::Emitter::EC->new();
		for my $cbx ( @{ $ec->linear } ) {
			#warn "linear call > @$cbx";
			eval {
				$cbx->[0]->( $obj, @_ );
			1 } or do {
				if ($ev eq '__DIE__') {
					warn "Unhandled callback exception on event `$ev': $_[0]\tduring exception callback: $@"
				} else {
					if ($obj->handles('__DIE__')) {
						$obj->event(__DIE__ => my $e = $@);
					} else {
						warn "Unhandled callback exception on event `$ev': $@\n";
					}
				}
				last;
			};
			if (defined $cbx->[1]) {
				$ec->del( $cbx->[0] ) if --$cbx->[1] <= 0;
			}
			last unless $FLOW{$id};
			
		}
	}
}

sub handled {
	my $obj = shift;
	my $id = refaddr $obj;
	! exists $FLOW{$id} and croak "Can't stop handling outside event handling";
	! $FLOW{$id} and carp ("Event handling already stopped"), return 0;
	$FLOW{$id} = 0;
	return 1;
}

package #hide
	Event::Emitter::Base;

*on = \&Event::Emitter::Core::on;
*once = \&Event::Emitter::Core::once;
*event = \&Event::Emitter::Core::event;
*emit = \&Event::Emitter::Core::emit;
*no = \&Event::Emitter::Core::no;
*handles = \&Event::Emitter::Core::handles;
*handled = \&Event::Emitter::Core::handled;

package #hide
	Event::Emitter::OEBase;

our @ISA = 'Event::Emitter::Base';

*reg_cb = \&Event::Emitter::Core::reg_cb;
*unreg_cb = \&Event::Emitter::Core::no;
*set_exception_cb = \&Event::Emitter::Core::die_cb;
*remove_all_callbacks = \&Event::Emitter::Core::no_all;

package #hide
	Event::Emitter::EC;

# Event Container

=for rem

1. Process events as fast as possible
2. Event addition
3. Event deletion (what about once events?)

=cut


sub new {
	my $pk = shift;
	return bless {
		defpri => 0,
		pri    => {},
		linear => undef,
	}, $pk;
}

sub head {
	my $self = shift;
	my $cb = pop;
	delete $self->{linear};
	my $pri = @_ ? shift : $self->{defpri};
	unshift @{ $self->{pri}{$pri} ||= [] }, $cb;
}

sub tail {
	my $self = shift;
	my $cb = pop;
	delete $self->{linear};
	my $pri = @_ ? shift : $self->{defpri};
	push @{ $self->{pri}{$pri} ||= [] }, $cb;
}
*add = \&head;

sub del {
	my $self = shift;
	my $cb = pop;
	delete $self->{linear};
	for my $pri (keys %{$self->{pri}} ) {
		@{ $self->{pri}{$pri} } = grep $_->[0] != $cb, @{ $self->{pri}{$pri} };
	}
}

sub linear {
	my $self = shift;
	$self->{linear} ||= do {
		my @linear;
		for my $pri (sort { $a <=> $b } keys %{$self->{pri}} ) {
			push @linear, @{ $self->{pri}{$pri} };
		}
		\@linear;
	}
}


sub count {
	my $self = shift;
	return 0+@{ $self->linear };
}



=head1 AUTHOR

Mons Anderson  <mons@cpan.org>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

=head1 COPYRIGHT

Copyright 2011 Mons Anderson, all rights reserved.

=cut

1;
