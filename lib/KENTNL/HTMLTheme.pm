use 5.006;
use strict;
use warnings;

package KENTNL::HTMLTheme;

# ABSTRACT: HTML and Theming glue

# AUTHORITY
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

use Set::Associate;
use Set::Associate::RefillItems;
use Set::Associate::NewKey;

my $set = Set::Associate->new(
    on_items_empty =>
      Set::Associate::RefillItems->linear( items => [NICK_COLORS], ),
    on_new_key => Set::Associate::NewKey->hash_sha1,
);

sub tr_iterator {
    my ($messages) = @_;
    my $last_day;
    return sub {
        my $payload = $messages->();
        return unless $payload;
        my $short_sender = $payload->sender_nick;
        my $message      = $payload->message;
        my $type         = $payload->type_name;

        my ( $display, $channel );

        if ( my $sub = __PACKAGE__->can( "event_" . $type ) ) {
            $display = $sub->($payload);
        }
        else {
            $display = event_DEFAULT($payload);
        }
        if ( my $sub = KENTNL::HTMLTheme->can( "channel_" . $type ) ) {
            $channel = $sub->($payload);
        }
        else {
            $channel = channel_DEFAULT($payload);
        }
        my (@out);

        if ( not $last_day or $last_day ne $payload->date ) {
            $last_day = $payload->date;
            push @out, tr_daychange($last_day);
        }
        push @out,
          info_tr(
            $payload->type_name,
            $payload->flags,
            $payload->to_pretty,
            td_channel($channel),
            td_time( $payload->message_id, $payload->time ),
            td_message($display),
          );
        return \@out;

    };
}

sub nick {
    my $color = get_color( $_[1] );
    return qq[<span class="nick" style="color: #$color">$_[0]</span>];
}

sub splitters_nick {
    my ($message) = @_;
    require KENTNL::Quassel;
    return join q[, ], map {
        nick(
            KENTNL::Quassel::sender_nick($_) || $_,
            KENTNL::Quassel::sender_mask($_) || $_,
        )
    } split /#:#/, $message;
}

sub get_color {
    return $set->get_associated( $_[0] );
}

sub tr_daychange {
    my ($date) = @_;
    return '<tr class="daychange"><td colspan=3>' . $date . '</td></tr>';
}

sub info_tr {
    my ( $type, $flags, $title, @tds ) = @_;
    $title =~ s/&/&amp;/g;
    $title =~ s/"/&quot;/g;
    $title =~ s/</&lt;/g;
    $title =~ s/>/&gt;/g;
    return
        qq[<tr class="type_$type flags_$flags" title="$title"\n>]
      . ( join qq[\n], @tds )
      . qq[</tr>\n];
}

sub head {
    return qq[<head>
    <meta charset="UTF-8">
    <style>@{[ style() ]}</style>
  </head>];
}

sub thead {
    my (@colmap) = @_;
    my $tds = "";
    while (@colmap) {
        $tds .= sprintf qq[<td class="%s">%s</td>\n], splice @colmap, 0, 2, ();
    }
    return "<thead><tr>$tds</tr></thead>";
}

sub td_channel {
    my $color = KENTNL::HTMLTheme::get_color( $_[0] );
    return qq[<td class="channel" style="color: #$color">$_[0]</td>];
}

sub td_time {
    my ( $id, $time ) = @_;
    return
qq[<td class="time" id="message_$id"><a href="#message_$id">[$time]</a></td>];
}

sub td_message {
    return "<td class=\"message\">" . $_[0] . "</td>";
}

sub hlnick {
    return nick( $_[0]->sender_nick, $_[0]->sender_mask );
}

sub event_plain {
    sprintf q[%s› %s], hlnick( $_[0] ), $_[0]->message;
}

sub event_DEFAULT {
    event_plain(@_);
}

sub event_join {
    sprintf q[─→ %s joined %s], hlnick( $_[0] ), $_[0]->message;
}

sub event_part {
    sprintf q[←─ %s left %s: %s], hlnick( $_[0] ), $_[0]->channel,
      $_[0]->message;
}

sub event_quit {
    event_part(@_);
}

sub event_action {
    sprintf q[∙%s %s], $_[0]->sender_nick, $_[0]->message;
}

sub event_notice {
    sprintf q[!- %s- %s], hlnick( $_[0] ), $_[0]->message;
}

sub event_mode {
    sprintf q[↑ %s set %s], hlnick( $_[0] ), $_[0]->message;
}

sub event_error {
    sprintf q[!! %s- %s], hlnick( $_[0] ), $_[0]->message;
}

sub event_kill {
    sprintf q[⇐═ %s left %s: %s], hlnick( $_[0] ), $_[0]->channel,
      $_[0]->message;
}

sub event_kick {
    event_kill(@_);
}

sub event_nick {
    sprintf q[∞  %s ─→ %s], hlnick( $_[0] ),
      nick( $_[0]->message, $_[0]->sender_mask );
}

sub event_netsplitjoin {
    sprintf q[∞→ %s], splitters_nick( $_[0]->message );
}

sub event_netsplitquit {
    sprintf q[←∞ %s], splitters_nick( $_[0]->message );
}

sub event_server {
    sprintf q[√  %s], $_[0]->message;
}

sub event_topic {
    sprintf q[⩴ %s], $_[0]->message;
}

sub channel_server {
    sprintf "net:" . substr $_[0]->network, 0, 15;
}

sub channel_topic {
    channel_server(@_);
}

sub channel_DEFAULT {
    $_[0]->channel;
}

sub style {
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
1;

