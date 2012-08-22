#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;

my $num_destroyed = 0;

package LL;

use Scalar::Util 'weaken';
use B 'svref_2object';

sub NAME () { 0 }
sub PREV () { 1 }
sub NEXT () { 2 }

my $global_phase_destroy; END { $global_phase_destroy = 1 }

sub new {
	my $self = bless [], shift;
	@$self = @_[ NAME .. NEXT ];
	weaken $self->[PREV];
	return $self;
}

sub name { $_[0][NAME] }
sub prev { $_[0][PREV] }
sub next { $_[0][NEXT] }

sub insert_after {
	my $self = shift;
	$self->[NEXT] = (ref $self)->new( $_[0], $self, $self->[NEXT] );
	#weaken $self->[NEXT];
	return $self->[NEXT];
}

sub insert_before {
	my $self = shift;
	$self->[PREV] = (ref $self)->new( $_[0], $self->[PREV], $self );
	weaken $self->[PREV];
	return $self->[PREV];
}

sub DESTROY {
	return if $global_phase_destroy;

	warn "Can $_[0][NAME] be rescued?";

	if ( ref $_[0][PREV] and svref_2object( $_[0][PREV] )->REFCNT > 1 ) {
		$_[0][PREV][NEXT] = $_[0];
		weaken( $_[0][PREV] );
		warn "$_[0][NAME] was rescued by $_[0][PREV][NAME]";
		return;
	}
	elsif ( ref $_[0][NEXT] and svref_2object( $_[0][NEXT] )->REFCNT > 1 ) {
		$_[0][NEXT][PREV] = $_[0];
		weaken( $_[0][NEXT] );
		warn "$_[0][NAME] was rescued by $_[0][NEXT][NAME]";
		return;
	}

	warn "$_[0][NAME] has no luck";

	$num_destroyed++;
}

package main;

use Test::More;

( my $ll = LL->new( 'foo' ) )->insert_after( 'bar' )->insert_after( 'baz' );

my $num_total = 0;

diag join ' -> ', do {
	my @name;
	my $i = $ll;
	while ( $i ) {
		++$num_total;
		push @name, $i->name;
		$i = $i->next;
	}
	@name;
};

$ll = $ll->next->next;
is $num_destroyed, 0, 'staying alive';

undef $ll;
is $num_destroyed, $num_total, 'DJ left the house';

done_testing;
