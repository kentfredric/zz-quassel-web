#!/usr/bin/env perl 

use strict;
use warnings;
use feature qw( fc postderef postderef_qq switch );
no warnings "experimental";
no warnings "experimental::postderef";

use lib 'lib';
use KENTNL::DB;
use KENTNL::DB::Messages;
use KENTNL::Data::Messages;

use constant PRUNE_CRUFT => $ENV{QUASSEL_PRUNE_CRUFT} || 0;

use KENTNL::HTMLTheme;
use KENTNL::Quassel;

my @table_rows;

my $q = KENTNL::DB::Messages->new(
    {
        cruft    => PRUNE_CRUFT,
        channels => [@ARGV],
    }
);
my $it = KENTNL::HTMLTheme::tr_iterator(  KENTNL::Data::Messages::iterator( KENTNL::DB::messages( $q->query_parts ) ) );

while ( my $payload = $it->() ) {
    push @table_rows, @{$payload};
}

my $HEAD = KENTNL::HTMLTheme::head();

print qq[<html lang="en">$HEAD<body><table cellpadding=0>]
  . KENTNL::HTMLTheme::thead(
    channel => 'Channel',
    time    => 'Time',
    message => 'Message',
  )
  . q[<tbody>]
  . ( join qq[\n], @table_rows )
  . q[</tbody></table>];

