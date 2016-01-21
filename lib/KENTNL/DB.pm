use strict;
use warnings;

package KENTNL::DB;

# ABSTRACT: Wrapper for DBI <-> Quassel

# AUTHORITY

use constant DB_PATH => "/var/lib/quassel/quassel-storage.sqlite";

use Data::Handle;
use DBI;

sub get_dbh {
    our $DBH;
    return ( $DBH ||= DBI->connect( "dbi:SQLite:dbname=" . DB_PATH, "", "" ) );
}

sub _get_messages {
    my ($xparams) = @_;
    my $query = _get_dh_section('get_messages');
    my (@params);
    if ( $xparams->{query} and length $xparams->{query} ) {
        $query .= " WHERE " . $xparams->{query};
        push @params, @{ $xparams->{params} };
    }
    my $sth = get_dbh->prepare($query);
    if ( $sth->execute(@params) ) {
        return $sth;
    }
    die "Query Failed";
}

sub messages {
    my ($xparams) = @_;
    my $sth = _get_messages($xparams);
    return sub {
        my %payload;
        if ( my $result = $sth->fetch ) {
            @payload{
                qw( timestamp channel sender message type flags network message_id )
            } = @{$result};
            return \%payload;
        }
        return;
    };
}

sub _get_dh_section {
    my ($name) = @_;
    my $dh = Data::Handle->new(__PACKAGE__);
  find_marker: {
        while ( my $line = <$dh> ) {
            last find_marker if $line =~ /^\%\s*\Q$name\E\s*$/;
            return;
        }
    }
    my $buf = "";
    while ( my $line = <$dh> ) {
        last if $line =~ /^\%\s*/;
        $buf .= $line;
    }
    return $buf;

}

1;

__DATA__
% get_messages
SELECT
  backlog.time,
  buffer.buffername,
  sender.sender,
  backlog.message,
  backlog.type,
  backlog.flags,
  network.networkname,
  backlog.messageid
FROM
	backlog 
JOIN buffer ON backlog.bufferid = buffer.bufferid
JOIN sender ON sender.senderid  = backlog.senderid
JOIN network ON network.networkid = buffer.networkid
