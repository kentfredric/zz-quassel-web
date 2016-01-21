use strict;
use warnings;

package KENTNL::Quassel;

# ABSTRACT: Various transforms from Quassel -> Userspace data

# https://github.com/quassel/quassel/blob/master/src/common/message.h#L34
our %MESSAGE_TYPES = (
    Plain        => 0x00001,
    Notice       => 0x00002,
    Action       => 0x00004,
    Nick         => 0x00008,
    Mode         => 0x00010,
    Join         => 0x00020,
    Part         => 0x00040,
    Quit         => 0x00080,
    Kick         => 0x00100,
    Kill         => 0x00200,
    Server       => 0x00400,
    Info         => 0x00800,
    Error        => 0x01000,
    DayChange    => 0x02000,
    Topic        => 0x04000,
    NetsplitJoin => 0x08000,
    NetsplitQuit => 0x10000,
    Invite       => 0x20000,
);
our %MESSAGE_IDS = ( map { $MESSAGE_TYPES{$_} => lc $_ } keys %MESSAGE_TYPES );
use feature qw( fc postderef );
no warnings "experimental::postderef";

use Hash::Util qw( lock_keys );
lock_keys(%MESSAGE_TYPES);
lock_keys(%MESSAGE_IDS);

sub type_name {
    my ($id) = @_;
    return $MESSAGE_IDS{$id};
}

sub sender_mask {
    my ( $sender ) = @_;
    if ( $sender =~ /!(.*$)/ ) {
      return $1;
    }
    return $sender;
}

sub sender_nick {
  my ( $sender ) = @_;
  if ( $sender =~ /^(.*?)!/ ) {
    return $1;
  }
  return;
}

1;
