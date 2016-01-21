use strict;
use warnings;
package KENTNL::DB::Messages;

# ABSTRACT: A messages query

# AUTHORITY

use Moo;

has 'msg_start' => (
  is => 'ro',
  predicate => 'has_msg_start',
);

has 'msg_stop' => (
  is => 'ro',
  predicate => 'has_msg_stop',
);

has 'age_max' => (
  is => 'ro',
  predicate => 'has_age_max',
  writer    => 'set_age_max',
);

has 'age_min' => (
  is => 'ro',
  predicate => 'has_age_min',
);

has 'channels' => (
   is => 'ro',
   predicate => 'has_channels',
);

has 'cruft'  => (
  is => 'ro',
  lazy => 1,
  default => sub { 0 },
);

has 'now' => (
  is => 'ro',
  default => sub { scalar time },
);

no Moo;

sub BUILD {
  my ( $self ) = @_;
  if ( not $self->has_msg_start and not $self->has_age_max ) {
    $self->set_age_max( 24 );
  }

}
sub age_offset {
  return ( $_[0]->now - ( $_[1] * 60 * 60 ));
}

sub query_parts {
  my ( $self ) = @_;
  my (@subqueries) = ( 
    $self->q_msg_start,
    $self->q_msg_stop,
    $self->q_age_max,
    $self->q_age_min,
    $self->q_channels,
    $self->q_cruft,
  );
  return {
    query => ( join qq[ AND ], map { $_->{query} } @subqueries ),
    params => [ map { @{ $_->{params} } } @subqueries ],
  };

}

sub q_msg_start {
  return unless $_[0]->has_msg_start;
  return { 
      query => 'backlog.messageid >= ?',
      params => [ $_[0]->msg_start ],
  };
}

sub q_msg_stop {
  return unless $_[0]->has_msg_stop;
  return {
      query => 'backlog.messageid <= ?',
      params => [ $_[0]->msg_stop ],
  };
}

sub q_age_max {
  return unless $_[0]->has_age_max;
  return {
      query => 'backlog.time >= ?',
      params => [ $_[0]->age_offset( $_[0]->age_max ) ],
  };
}

sub q_age_min {
  return unless $_[0]->has_age_min;
  return {
    query => 'backlog.time <= ?',
    params => [ $_[0]->age_offset( $_[0]->age_min ) ],
  };
}

sub q_channels {
  return unless $_[0]->has_channels;
  return unless @{ $_[0]->channels };
  my $qns = join q[,], map { '?' } @{ $_[0]->channels };
  return {
      query => 'buffer.buffername IN ( ' . $qns . ')',
      params => [@{ $_[0]->channels } ],
  };
}

sub q_cruft {
  return if $_[0]->cruft;
  return {
    query => 'backlog.type IN ( 1,2,4 )',
    params => [],
  };
}

1;
