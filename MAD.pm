package MAD;

use Scalar::Util qw( weaken isweak );
use B 'svref_2object';
#use Hash::Util::FieldHash 'fieldhash';

my %peer_lister; # class -> coderef
sub import {
	my $class = shift;
	my $pkg = caller;
	$peer_lister{ $pkg } = $_[0];
	warn join ' ', keys %peer_lister;
	no strict 'refs';
	*{ $pkg . '::rescued_by_peer' } = \&rescued_by_peer;
}

# fieldhash my %peers; # instanceref -> { instanceref -> refref }
# 
# sub register_peer {
# 	my $peerref = $peers{ $_[0] } || do { fieldhash my %peerref; \%peerref };
# 	weaken $peerref{ $_[1] } = \$_[1];;
# 	return;
# }

my $global_phase_destroy; END { $global_phase_destroy = 1 }

sub get_peers {
	my @peer; # = grep defined, @{ $peers{ $_[0] } // [] };
	if ( my $peer_lister = $peer_lister{ ref $_[0] } ) {
		push @peer, &$peer_lister;
	}
	return @peer;
}

# find first peer that is not about to be GCed (someone other than $self
# holds a reference to it) and reattach to it, weakening our own link

sub rescued_by_peer {
	return if $global_phase_destroy;

	warn "Can $_[0][NAME] be rescued?";

	my @peer = &get_peers;

	for my $peer_rr ( @peer ) {
		next if not ref $$peer_rr;
		next if svref_2object( $$peer_rr )->REFCNT <= 1;
		for my $their_peer_rr ( get_peers $$peer_rr ) {
			if ( $$their_peer_rr == $_[0] ) {
				$$their_peer_rr = $_[0]; # strengthen ref
				weaken $$peer_rr unless isweak $$peer_rr;
				warn "$_[0][NAME] was rescued by $$peer_rr->[NAME]";
				return 1;
			}
		}
		die "wtf?";
	}

	# for my $peer_rr ( @peer ) {
	# 	return 1 if rescued_by_peer $$peer_rr;
	# }

	warn "$_[0][NAME] has no luck";

	return;
}

1;
