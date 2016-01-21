#!/usr/bin/env perl 

use strict;
use warnings;
use feature qw( fc postderef postderef_qq switch );
no warnings "experimental";
no warnings "experimental::postderef";

use lib 'lib';
use KENTNL::DB;

use constant PRUNE_CRUFT => $ENV{QUASSEL_PRUNE_CRUFT} || 0;

use constant NICK_COLORS =>
  qw( 500 050 005 550 505 055 922 292 229 992 929 299 d44
  4d4 44d dd4 d4d 4dd );

use constant JOINQUITS_COLOR    => '#cac';
use constant NETSPLITS          => '#d77';
use constant MESSAGE_BACKGROUND => '#fff';
use constant MESSAGE_COLOR      => '#000';
use constant MESSAGE_SIZE       => '14px';
use constant NOISE_COLOR        => '#ccc';
our %THEME = (
    'daychange.background.color'      => '#f4f4f4',
    'daychange.border.bottom.color'   => '#f0f0f0',
    'daychange.border.color'          => '#f7f7f7',
    'daychange.text.color'            => '#777',
    'message.action.background.color' => MESSAGE_BACKGROUND,
    'message.action.text.color'       => MESSAGE_COLOR,
    'message.action.text.size'        => MESSAGE_SIZE,
    'message.daychange.text.color'    => NOISE_COLOR,
    'message.error.text.color'        => NOISE_COLOR,
    'message.info.text.color'         => NOISE_COLOR,
    'message.invite.text.color'       => NOISE_COLOR,
    'message.join.text.color'         => JOINQUITS_COLOR,
    'message.kick.text.color'         => JOINQUITS_COLOR,
    'message.kill.text.color'         => JOINQUITS_COLOR,
    'message.modechange.text.color'   => '#770',
    'message.netsplitjoin.text.color' => NETSPLITS,
    'message.netsplitquit.text.color' => NETSPLITS,
    'message.nickchange.text.color'   => '#77f',
    'message.notice.text.color'       => '#f77',
    'message.part.text.color'         => JOINQUITS_COLOR,
    'message.plain.background.color'  => MESSAGE_BACKGROUND,
    'message.plain.text.color'        => MESSAGE_COLOR,
    'message.plain.text.size'         => MESSAGE_SIZE,
    'message.quit.text.color'         => JOINQUITS_COLOR,
    'message.server.text.color'       => NOISE_COLOR,
    'message.topic.text.color'        => '#6cc',
    'noiseline.text.color'            => NOISE_COLOR,
    'noiseline.text.size'             => '10px',
    'page.background'                 => '#fafafa',
);
use Hash::Util qw( lock_keys );
lock_keys(%THEME);

my $blacklist = { map { fc $_ => 1 } qw( Nickserv Chanserv ) };

my @table_rows;

my $sth = query_messages( PRUNE_CRUFT ? { prune_cruft => 1 } : (), @ARGV )
  or die "Query failed";

while ( my $record = $sth->fetch ) {
    my $payload = query_messages_record($record);
    next if exists $blacklist->{ fc $payload->{channel} };
    next if exists $blacklist->{ fc $payload->{short_sender} };

    my ($short_sender,$message,$type) = @{$payload}{qw( short_sender message type )};

    my $hlnick = FMT_nick( $short_sender, $payload->{sender_ident} );
    my $display = "$hlnick› $message";

    given ($type) {
        break when /^plain$/;

        $display = "∙$short_sender $message" when /^action$/;

        $display = "!- $hlnick- $message" when /^notice$/;

        $display = "↑  $hlnick set $message" when /^mode$/;

        $display = "─→ $hlnick joined $message" when /^join$/;

        $display =
          "←─ $hlnick left $payload->{channel}: $message" when
          /^part|quit$/;

        $display = qq[∞  $hlnick ─→ ]
          . FMT_nick( $message, $payload->{sender_ident} ) when /^nick$/;

        $display = "!! $hlnick- $message" when /^error$/;

        $display = "∞→ " . FMT_splitters($payload) when /^netsplitjoin$/;
        $display = "←∞ " . FMT_splitters($payload) when /^netsplitquit$/;

        when (/^kill|kick$/) {
            $display = "⇐═ $hlnick left $payload->{channel}: $message";
        }

        when (/^server$/) {
            $payload->{channel} = "net:" . substr $payload->{network}, 0, 15;
            $display = "√  $message";
        }

        when (/^topic$/) {
            $payload->{channel} = "net:" . substr $payload->{network}, 0, 15;
            $display = "⩴ $message";
        }

    }

    $payload->{display} = $display;
    insert_daychange( $payload, \@table_rows );

    push @table_rows, xtr($payload);
}

my $HEAD = html_head();
print qq[<html lang="en">$HEAD<body><table cellpadding=0>]
  . xtrh()
  . q[<tbody>]
  . ( join qq[\n], @table_rows )
  . q[</tbody></table>];

## Functions --------------------------------------------------------------------------------------------------
##

sub FMT_splitters {
    return join q[, ],
      map { FMT_nick( short_sender($_), sender_ident($_) ) } split /#:#/,
      $_[0]->{message};
}

sub FMT_nick {
    my ( $nick, $ident ) = @_;
    my $color = get_color($ident);
    return qq[<span class="nick" style="color: #$color">$nick</span>];
}

sub get_dbh {
    require DBI;
    our $DBH;
    return ( $DBH ||= DBI->connect( "dbi:SQLite:dbname=" . DB_PATH, "", "" ) );
}

sub query_messages {
    my (@channels) = @_;
    my $param_hash = ref $channels[0] ? { %{ shift @channels } } : {};

    my $QUERY = <<"QUERY";
select backlog.time,buffer.buffername,sender.sender,backlog.message,backlog.type,backlog.flags,network.networkname,backlog.messageid from 
	backlog 
		join buffer on backlog.bufferid = buffer.bufferid
		join sender on sender.senderid  = backlog.senderid
		join network on network.networkid = buffer.networkid
QUERY
    my @PARAMS;
    my @WHERE;
    if (@channels) {
        push @WHERE, 'buffer.buffername IN ('
          . ( join qq[,], map { '?' } @channels ) . ')';
        push @PARAMS, @channels;
    }
    if ( $param_hash->{'prune_cruft'} ) {
        push @WHERE, 'backlog.type IN ( 1,2,4 )';
    }
    if (@WHERE) {
        $QUERY .= "WHERE " . join q[ AND ], @WHERE;
    }
    my $sth = get_dbh->prepare($QUERY);
    if ( $sth->execute(@PARAMS) ) {
        return $sth;
    }
}

sub query_messages_record {
    my %payload;
    @payload{
        qw( timestamp channel sender message type flags network message_id )
    } = @{ $_[0] };
    $payload{message_type} = message_type( $payload{type} );
    $payload{short_sender} = short_sender( $payload{sender} );
    $payload{sender_ident} = sender_ident( $payload{sender} );
    $payload{time}         = gmtime $payload{timestamp};
    $payload{short_time}   = short_time( $payload{timestamp} );
    $payload{localtime}    = localtime $payload{timestamp};
    return \%payload;
}
my ( $msg_types, $mid_type );

BEGIN {
    #https://github.com/quassel/quassel/blob/master/src/common/message.h#L34
    $msg_types = {
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
    };
    $mid_type = {};
    for my $type ( keys %{$msg_types} ) {
        $mid_type->{ $msg_types->{$type} } = lc $type;
    }
    lock_keys(%$mid_type);
}

sub message_type {
    return $mid_type->{ $_[0] };
}

sub sender_ident {
    my $name = $_[0];
    $name =~ s/^.*!//;
    return $name;
}

sub short_sender {
    my $name = $_[0];
    $name =~ s/!.*$//;
    return $name;
}

sub short_time {
    return join q[:], map { sprintf "%02d", $_ }[ gmtime $_[0] ]->@[ 2, 1, 0 ];
}

my $set;

BEGIN {
    use Set::Associate;
    use Set::Associate::RefillItems;
    use Set::Associate::NewKey;

    $set = Set::Associate->new(
        on_items_empty =>
          Set::Associate::RefillItems->linear( items => [NICK_COLORS], ),
        on_new_key => Set::Associate::NewKey->hash_sha1,
    );
}

sub get_color {
    return $set->get_associated( $_[0] );
}

my $last_day;

sub insert_daychange {
    my ( $payload, $rows ) = @_;
    my ( $y, $m, $d ) = [ gmtime $payload->{timestamp} ]->@[ 5, 4, 3 ];
    my ($datestamp) = join "-", $y + 1900, $m + 1, $d;
    if ( not $last_day or $last_day ne $datestamp ) {
        $last_day = $datestamp;
        push $rows->@*,
          '<tr class="daychange"><td colspan=3>' . $last_day . '</td></tr>';
    }
}

sub tdh_channel {
    return "" if @ARGV == 1;
    return "<td class=\"channel\">Channel</td>";
}

sub td_channel {
    my %payload = $_[0]->%*;
    return "" if @ARGV == 1;
    my $color = get_color( $payload{channel} );
    return
      "<td class=\"channel\" style=\"color: #$color\">"
      . $payload{channel} . "</td>";
}

sub tdh_message {
    return "<td class=\"message\">Message</td>";
}

sub tdh_time {
    return "<td class=\"time\">Time</td>";
}

sub td_time {
    return
qq[<td class="time" id="message_$_[0]->{message_id}"><a href="#message_$_[0]->{message_id}">[$_[0]->{short_time}]</a></td>];
}

sub td_message {
    return "<td class=\"message\">" . $_[0]->{display} . "</td>";
}

sub xtrh {
    return
        "<thead><tr>"
      . tdh_channel
      . tdh_time
      . tdh_message
      . "</tr></thead>";
}

my $xtr_filter;

BEGIN {
    $xtr_filter = { map { $_ => 1 } qw( display ) };
}

sub xtr {
    my $pp_payload = join qq[\n], map { "$_: $_[0]->{$_}" }
      grep { not exists $xtr_filter->{$_} } sort keys $_[0]->%*;
    $pp_payload =~ s/&/&amp;/g;
    $pp_payload =~ s/"/&quot;/g;
    $pp_payload =~ s/</&lt;/g;
    $pp_payload =~ s/>/&gt;/g;
    return
"<tr class=\"type_$_[0]->{message_type} flags_$_[0]->{flags}\" title=\"$pp_payload\">\n"
      . td_channel( $_[0] )
      . td_time( $_[0] )
      . td_message( $_[0] )
      . "</tr>\n";
}

sub html_head {
    my $style = stylesheet();
    return <<"HEAD";
<head>
	<meta charset="UTF-8">
	<style>$style</style>
</head>
HEAD

}

sub stylesheet {
    return <<"STYLE";
html, body, tr {
	background-color: $THEME{'page.background'};
}
a {
	text-decoration: inherit;
	color: inherit;
}
tr {
	padding: 0;
	margin: 0;
	color: $THEME{'noiseline.text.color'};
	white-space: pre-wrap;
	font-family: "Fira Mono", monospace;
	font-size: $THEME{'noiseline.text.size'};
	border-spacing: 0;
	line-height: 1em;
}
tr.daychange td {
	text-align: center;
	border: 1px dotted $THEME{'daychange.border.color'};
	background-color: $THEME{'daychange.background.color'};
	color: $THEME{'daychange.text.color'};
	border-bottom: 2px double $THEME{'daychange.border.bottom.color'};
	border-radius: 20px 20px 0 0;
}
td {
	border: 0;	//	border-right: 1px solid #ccc; 
	border-spacing: 0;
	border-bottom: 0;
	padding: 0;
	margin: 0;
	vertical-align: top;
}
span.nick {
	font-weight: bold;
}
td.channel {
	text-align: right;
}
td.time {
	text-align: center;
}
td.message {
	padding-left: 3px;
}
tr.type_plain {
	font-size: $THEME{'message.plain.text.size'};
	background-color: $THEME{'message.plain.background.color'};
}
tr.type_action {
	font-size: $THEME{'message.action.text.size'};
	background-color: $THEME{'message.action.background.color'};
}
tr.type_plain td.message {
	color: $THEME{'message.plain.text.color'};
}
tr.type_action td.message {
	color: $THEME{'message.action.text.color'};
}
tr.type_notice td.message{ 
	color: $THEME{'message.notice.text.color'};
}
tr.type_nickchange td.message {
	color: $THEME{'message.nickchange.text.color'};
}
tr.type_mode td.message {
	color: $THEME{'message.modechange.text.color'};
}
tr.type_join td.message {
	color: $THEME{'message.join.text.color'};
}
tr.type_part td.message {
	color: $THEME{'message.part.text.color'};
}
tr.type_quit td.message {
	color: $THEME{'message.quit.text.color'};
}
tr.type_kick td.message {
	color: $THEME{'message.kick.text.color'};
}
tr.type_kill td.message {
	color: $THEME{'message.kill.text.color'};
}
tr.type_server td.message {
	color: $THEME{'message.server.text.color'};
}
tr.type_info td.message {
	color: $THEME{'message.info.text.color'};
}
tr.type_error td.message {
	color: $THEME{'message.error.text.color'};
}
tr.type_daychange td.message {
	color: $THEME{'message.daychange.text.color'};
}
tr.type_topic {
	color: $THEME{'message.topic.text.color'};
}
tr.type_netsplitjoin {
	color: $THEME{'message.netsplitjoin.text.color'};
}
tr.type_netsplitquit {
	color: $THEME{'message.netsplitquit.text.color'};
}
tr.type_invite {
	color: $THEME{'message.invite.text.color'};
}
STYLE

}
