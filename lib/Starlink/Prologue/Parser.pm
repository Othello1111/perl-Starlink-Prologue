package Starlink::Prologue::Parser;

=head1 NAME

Starlink::Prologue::Parser - Parse a source code file and extract prologue

=head1 SYNOPSIS

  use Starlink::Prologue::Parser;

  $p = new Starlink::Prologue::Parser();

  for my $l (@lines) {
    my $status = $p->push_line( $l );
  }


=head1 DESCRIPTION

This class is responsible for parsing source code and creating
C<Starlink::Prologue> objects. This class is made more complex since
it is not clear which form of Starlink prologue will be encountered
until lines appear.

=cut

use 5.006;
use strict;
use warnings;
use Carp;

use Starlink::Prologue;
use Starlink::Prologue::Parser::STARLSE;
use Starlink::Prologue::Parser::ADAMSSE;

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new base parser

  $p = new Starlink::Prologue::Parser;

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $p = bless {
		 WORKER => undef,
		}, $class;

  return $p;
}


=back

=head2 Accessors

=over 4

=back

=head2 General

=over 4

=item B<push_line>

Add a new line of content to the parser. In scalar context returns the
line itself if the line is not part of a prologue, returns undef if
the line was part of a prologue and returns a C<Starlink::Prologue>
object if the line completes a prologue. This usage is adequate if only
the prologue is being extracted, as opposed to rewriting the prologue.

  $result = $parser->prologue;

Since some prologues are only terminated when the first line of code is
discovered, it is sometimes necessary to return both a line of code and the
relevant prologue. If the prologue is being rewritten and code lines are
not being discarded, the C<push_line> method should be called in list context
where both a line and prologue can be returned simultaneously. Either the line
or prologue or both can be undef depending on context.

  ($line, $prologue) = $parser->push_line( $input );

The returned line will not have a newline character.

=cut

sub push_line {
  my $self = shift;
  my $line = shift;
  chomp($line);

  # if we are in a prologue then we simply pass this to the worker
  # if we are not in a prologue and this is the start of one, we need
  # to create the specific parser
  # if this is an end we should destroy the worker parser

  my $worker = $self->_worker();

  if (defined $worker) {
    # currently in a prologue
    my @status = $worker->push_line($line);

    # we should only be getting undef or a prologue object
    # unless we are at the top of an old style prolog.
    if (defined $status[1]) {
      if (ref($status[1]) ) {
	# finished this prologue
	$self->_worker( undef );
      }
    }
    if ( wantarray() ) {
      return @status;
    } else {
      if (defined $status[1]) {
        # prologue takes priority in scalar context
        return $status[1];
      } else {
        # return line or undef
        return $status[0];
      }
    }


  } else {
    # not in a prologue, so this might be a start of prologue
    my @classes = qw/ STARLSE ADAMSSE /;
    my $match;
    for my $c (@classes) {
      # try each class in turn
      my $try = "Starlink::Prologue::Parser::$c";
      if ($try->prolog_start($line)) {
	$match = $try;
	last;
      }
    }

    if (defined $match) {
      # create a object
      my $w = $match->new();
      $self->_worker( $w );
      return $w->push_line( $line );
    } else {
      # not a prolog start
      return ($line, undef);
    }
  }

}

=item B<flush>

Indicate that no more content is arriving for the current
parser. This should be called after a set of C<push_line>
calls when no more lines are expected.

 $prl = $parser->flush();

Returns undef if a prologue was not in progress, else returns
the current prologue (in as complete a state as was available).

The internal state is reset after this is called, any new lines
added to C<push_line> will be treated as a new prologue.

=cut

sub flush {
  my $self = shift;

  my $worker = $self->_worker;
  if (!defined $worker) {
    # no active worker so either no prologue or it was 
    # already complete.
    return;
  } else {
    my $prl = $worker->flush;
    $self->_worker( undef );
    return $prl;
  }

}


=back

=begin __INTERNAL__

=head2 Internal

=over 4

=item B<_worker>

Underlying parser object responsible for this particular style
of header.

=cut

sub _worker {
  my $self = shift;
  if (@_) {
    $self->{WORKER} = shift;
  }
  return $self->{WORKER};
}

=back

=end __INTERNAL__


=head1 SEE ALSO

C<Starlink::Prologue>

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2006 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
