use strict;
use warnings;

package KENTNL::Data::Messages;

# ABSTRACT: Add spice to messages payload

# AUTHORITY
use feature qw( fc postderef );
use KENTNL::Quassel;
use Moo;
no warnings "experimental::postderef";

has 'timestamp' => (
    is       => 'ro',
    required => 1,
);

has 'channel' => (
    is       => 'ro',
    isa      => sub {
        die "channel is undefined" unless defined $_[0];
    },
    required => 1,
);

has 'sender' => (
    is       => 'ro',
    required => 1,
);

has 'message' => (
    is       => 'ro',
    required => 1,
);

has 'message_id' => (
    is => 'ro',
    required => 1,
);

has 'type' => (
    is       => 'ro',
    required => 1,
);
has 'flags' => (
    is       => 'ro',
    required => 1,
);
has 'network' => (
    is       => 'ro',
    required => 1,
);
has 'type_name' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { KENTNL::Quassel::type_name( $_[0]->type ) }
);
has 'sender_mask' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { KENTNL::Quassel::sender_mask( $_[0]->sender ) or $_[0]->sender },
);
has 'sender_nick' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { KENTNL::Quassel::sender_nick( $_[0]->sender ) or $_[0]->sender },
);
has 'time' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub {
        join q[:],
          map { sprintf "%02d", $_ }[ gmtime $_[0]->timestamp ]->@[ 2, 1, 0 ];
    },
);
has 'date' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub {
        my ( $y, $m, $d ) = [ gmtime $_[0]->timestamp ]->@[ 5, 4, 3 ];
        return sprintf "%04d-%02d-%02d", $y + 1900, $m + 1, $d;
    }
);

has 'gmtime' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub {
        scalar gmtime $_[0]->timestamp;
    },
);
has 'localtime' => (
    is      => 'ro',
    lazy    => 1,
    builder => sub {
        scalar localtime $_[0]->timestamp;
    },
);

my $xtr_filter = { map { $_ => 1 } qw( display ) };

sub to_pretty {
    my ( $self ) = @_;
    return join qq[\n], map { "$_: $_[0]->{$_}" }
      grep { not exists $xtr_filter->{$_} } sort keys $_[0]->%*;
}

sub BUILD {
    $_[0]->type_name;
    $_[0]->sender_mask;
    $_[0]->sender_nick;
    $_[0]->time;
    $_[0]->gmtime;
    $_[0]->localtime;
    $_[0]->date;
}

no Moo;

my $blacklist = { map { fc $_ => 1 } qw( Nickserv Chanserv ) };

sub blacklisted {
    return 1 if exists $blacklist->{ fc $_[0]->channel };
    return 1 if exists $blacklist->{ fc $_[0]->sender_nick };
    return;
}

sub iterator {
    my ($dbi_iterator) = @_;
    return sub {
        while ( my $row = $dbi_iterator->() ) {
            my $instance = __PACKAGE__->new($row);
            next if $instance->blacklisted;
            return $instance;
        }
        return;
    };
}

1;

