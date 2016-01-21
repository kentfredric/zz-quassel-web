#!/usr/bin/env perl
# FILENAME: http_server.pl
# CREATED: 01/21/16 10:00:24 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Simple web-servert

use strict;
use warnings;

use Web::Simple;
use Path::Tiny;
use lib 'lib';

sub dispatch_request {
    my %rules;
    $rules{'GET + /sqlite.html'} = sub {
        return $_[0]->stream_html_file('/tmp/sqlite.html');
    };
    my (@messages_params) = qw(
      :msg_start~      :msg_stop~
      :age_max~        :age_min~
      :@channels~      :cruft~
    );
    $rules{ 'GET + /messages/ +  ? ' . join q[&], @messages_params } = sub {
        return $_[0]->messages_query( $_[1] );
    };
    $rules{'GET + /messages-help/'} = sub {
        return $_[0]->messages_help();
    };
    return %rules;
}

sub messages_help {

     return [ '200', [ 'Content-Type' => 'text/html' ], [<<'HTML'] ];

<pre><code>
  /messages/
    ? 
      msg_start = n       ( undef )
      msg_stop  = n       ( undef )
      age_max   = n_hours ( 24 by default )
      age_min   = n_hours ( undef )
      channels  = @channel_name
      channels  = user_name ( all by default )
      cruft     = 1/0     ( 0 by default )
</code></pre>
<ul>
 <li>
  <a href="/messages/?msg_start=0&cruft=1&channels=@toolchain&channels=ribasushi">/messages/?msg_start=0&cruft=1&channels=@toolchain&channels=ribasushi</a>
  </li>
  <li>
   <a href="/messages/?msg_start=880&msg_stop=923&cruft=1&channels=@perl.today&channels=ribasushi">/messages/?msg_start=880&msg_stop=923&cruft=1&channels=@perl.today&channels=ribasushi</a>
   </li>
   <li>
    <a href="/messages/?msg_start=880&msg_stop=923&cruft=1">/messages/?msg_start=880&msg_stop=923&cruft=1</a>
  </li>
</ul>
HTML

}

sub stream_html_file {
    return [
        '200',
        [ 'Content-Type' => 'text/html' ],
        path( $_[1] )->openr_raw
    ];
}

sub messages_query {
    my ( $self, $params ) = @_;
    require KENTNL::DB::Messages;
    require KENTNL::DB;
    require KENTNL::Data::Messages;
    require KENTNL::HTMLTheme;

    require Data::Dump;
    if ( $params->{channels} ) {
        $params->{channels} =
          [ map { $_ =~ s/^@/#/; $_ } @{ $params->{channels} } ];
    }
    my $it = KENTNL::HTMLTheme::tr_iterator(
        KENTNL::Data::Messages::iterator(
            KENTNL::DB::messages(
                KENTNL::DB::Messages->new( %{$params} )->query_parts,
            )
        )
    );
    my @rows;

    while ( my $payload = $it->() ) {
        push @rows, @{$payload};
    }
    my $HEAD = KENTNL::HTMLTheme::head();

    my $HTML = qq[<html lang="en">$HEAD<body><table cellpadding=0>]
      . KENTNL::HTMLTheme::thead(
        channel => 'Channel',
        time    => 'Time',
        message => 'Message',
      )
      . q[<tbody>]
      . ( join qq[\n], @rows )
      . q[</tbody></table></body></html>];

    return [ '200', [ 'Content-Type' => 'text/html' ], [$HTML] ];
}

__PACKAGE__->run_if_script;

