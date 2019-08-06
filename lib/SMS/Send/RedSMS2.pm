package SMS::Send::RedSMS2;
use strict;
use warnings;
our $VERSION = '0.001';

use LWP::UserAgent;
use Time::HiRes;
use Digest::MD5   ();
use JSON::MaybeXS ();
use URI::Escape   ();
use Carp qw(croak);

use base 'SMS::Send::Driver';

sub new {
    my ( $class, %args ) = @_;

    unless ( $args{'_login'} && $args{'_api'} ) {
        croak '_login, _api are required';
    }

    my $self = bless \%args, $class;

    if ( !exists( $self->{_endpoints} ) ) {
        $self->{_endpoints}->{send}    = 'https://cp.redsms.ru/api/message';
        $self->{_endpoints}->{status}  = 'https://cp.redsms.ru/api/message';
        $self->{_endpoints}->{balance} = 'https://cp.redsms.ru/api/client/info';
    }

    $self->{_timeout} = 10 if ( !exists( $self->{_timeout} ) );

    $self->{_route} = 'sms' if ( !exists( $self->{_route} ) );

    $self->{_ua} = LWP::UserAgent->new(
        agent   => join( '/', $class, $VERSION ),
        timeout => $self->{_timeout}
    );

    return $self;
}

sub send_sms {
    my ( $self, %args ) = @_;

    if ( !$args{to} || !$args{text} ) {
        croak 'to and text are required';
    }
    my $params = { to => $args{to}, text => $args{text} };

    foreach (
        qw(from route translit phoneDelimeter textDelimeter validity sms.from sms.text sms.to sms.validity vk.from vk.text vk.to vk.validity viber.from viber.text viber.to viber.validity viber.btnText viber.btnUrl viber.imageUrl)
      )
    {
        if ( exists( $self->{ '_' . $_ } ) && defined( $self->{ '_' . $_ } ) ) {
            $params->{$_} = $self->{ '_' . $_ };
        }
    }

    my ( $response, $error ) =
      $self->_query( 'POST', $self->{_endpoints}->{send}, $params );

    $self->{result} = {
        to       => $args{to},
        error    => $error,
        response => $response,
        items    => {},
        count    => 0
    };

    if ( $error || !$response ) {
        $@ = $error;
        return 0;
    }

    if ( ref($response) ne "HASH" ) {
        $@ = 'Wrong server answer';
        return 0;
    }

    if ( exists( $response->{errors} ) ) {
        if ( ref( $response->{errors} ) eq "ARRAY" ) {
            foreach ( @{ $response->{errors} } ) {
                $self->{result}->{items}->{ $_->{to} }->{error} = $_->{message};
            }
        }
        $self->{result}->{errors} = $response->{errors};
    }

    if ( !$response->{success} ) {
        $@ = 'Unsuccessful operation';
        return 0;
    }

    if ( !exists( $response->{items} ) ) {
        $@ = 'No messages were sent';
        return 0;
    }

    foreach ( @{ $response->{items} } ) {
        $self->{result}->{items}->{ $_->{to} }->{uuid} = $_->{uuid}
          if ( ref($_) eq 'HASH' );
    }

    $self->{result}->{count} = $response->{count};

    return 1;
}

sub status {
    my ( $self, @list ) = @_;

    if ( !@list ) {
        croak 'At least one sms-id (uuid) is required';
    }

    my %status;

    map { $status{$_} = 0 } @list;

    my $data = $self->info( uuid => join( ',', @list ) );

    map { $status{$_} = 1 if ( $data->{$_}->{status} eq 'delivered' ) }
      keys %$data;

    return \%status;
}

sub info {
    my ( $self, %filter ) = @_;

    my @required =
      qw(uuid type source from status to dispatchId dispatchSectionId createdAtFrom createdAtTo);
    my @optional = qw(fields limit offset page);

    my %available = map { ; $_ => 1 } ( @required, @optional );

    map { croak 'Unknown filter: ' . $_ if ( !exists( $available{$_} ) ) }
      keys %filter;

    my $required = 0;
    map { $required++ if ( defined( $filter{$_} ) ) } @required;

    croak 'You must set at least one required filter parameter: '
      . join( ',', @required )
      if ( !$required );

    $filter{fields} = 'all' if ( !defined( $filter{fields} ) );

    my ( $response, $error ) =
      $self->_query( 'GET', $self->{_endpoints}->{status}, \%filter );

    if ( $error || !$response ) {
        $@ = $error;
        return {};
    }

    if ( ref($response) ne "HASH" ) {
        $@ = 'Wrong server answer';
        return {};
    }

    foreach (qw(count offse total items)) {
        $self->{result}->{$_} = $response->{$_}
          if ( exists( $response->{$_} ) );
    }

    my %status = ();

    if ( exists( $response->{items} ) ) {
        foreach ( @{ $response->{items} } ) {
            $status{ $_->{uuid} }->{status}      = $_->{status};
            $status{ $_->{uuid} }->{status_time} = $_->{status_time};
        }
    }

    return \%status;
}

sub balance {
    my $self = $_[0];
    my ( $response, $error ) =
      $self->_query( 'GET', $self->{_endpoints}->{balance} );

    if ( $error || !$response ) {
        $@ = $error;
        return -1;
    }

    if ( ref($response) ne "HASH" || !exists( $response->{info} ) ) {
        $@ = 'Wrong server answer';
        return -1;
    }

    $self->{result} = $response->{info};

    return $response->{info}->{balance};
}

sub _get_headers {
    my ( $self, $data ) = @_;
    my $ts = Time::HiRes::time();
    return (
        ts     => $ts,
        login  => $self->{_login},
        secret => Digest::MD5::md5_hex( $ts . $self->{_api} )
    );
}

sub _query {
    my ( $self, $type, $url, $data ) = @_;

    my $content;
    if ($data) {
        $content = join '&',
          map { $_ . '=' . URI::Escape::uri_escape_utf8( $data->{$_} ) }
          keys %$data;
    }

    if ( $type eq 'GET' && $content ) {
        $url .= '?' . $content;
    }

    my $request = HTTP::Request->new( $type => $url );

    if ( $type ne 'GET' && $content ) {
        $request->content($content);
        $request->content_type('application/x-www-form-urlencoded');
    }

    $request->header( $self->_get_headers($data) );

    my $res = $self->{_ua}->request($request);

    my $response;
    eval { $response = JSON::MaybeXS::decode_json( $res->content ); };
    if ( !$@ ) {
        if ( $res->is_success ) {
            return ( $response, undef );
        }
        else {
            return ( undef, $response->{error_message} );
        }
    }
    return ( undef, 'Wrong JSON format' );
}

=pod

=encoding UTF-8

=head1 NAME

SMS::Send::RedSMS2 - SMS::Send driver to send messages via RedSMS.ru service (https://redsms.ru) API 2.0

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use SMS::Send;
    my $api = SMS::Send->new('RedSMS2',
        _login    => 'your login',
        _api => 'your api key',
        _from => 'your approved sender name',
    );

    my $sent = $api->send_sms(
        'to'             => '+70001234567',
        'text'           => 'This is a test message'
    );

    # Did the send succeed.
    if ( $sent ) {
        print "Message sent ok\n";
    } else {
        print 'Failed to send message: ', $@, "\n";
    }

    # Get info about the last operation
    my $info = $api->{OBJECT}->{result};

    # Get sms-id (uuid) of the last sent sms
    print $api->{OBJECT}->{result}->{response}->{items}->[0]->{uuid};

    # Show your balance
    print $api->balance();

    # Get sms delivery status
    $status = $api->status('sms-id 1', 'sms-id 2', ..., 'sms-id N');
    print $status->{'sms-id 1'};

    # Get info about sent messages with filter:
    $info = $api->info(to=>'70001234567');
    # or
    $info = $api->info(uuid=>'0794e72e-9b64-43bf-ba80-83c74a1ba096,9044f5aa-292b-4c4a-bd7d-17ecd211a54b,...');

    # Show error text of the last failed operation
    print $@;

=head1 DESCRIPTION

SMS::Send driver for RedSMS - L<https://www.redsms.ru/>

This is not intended to be used directly, but instead called by SMS::Send (see
synopsis above for a basic illustration, and see SMS::Send's documentation for
further information).

The driver uses the RedSMS HTTP API mechanism (cp.redsms.ru version) with JSON.

=head1 METHODS

=head2 new

    # Create a new sender using this driver
    my $api = SMS::Send->new('RedSMS2',
        _login    => 'your login',
        _api => 'your api key',
        _from => 'your approved sender name',
    );

Additional arguments that may be passed include:

=over 3

=item _endpoints

A hashref with HTTP API endpoints. Default are:

    _endpoints=>
    {
        send=>'https://cp.redsms.ru/api/message',
        status=>'https://cp.redsms.ru/api/message',
        balance=>'https://cp.redsms.ru/api/client/info'
    }

=item _route

RedSMS.ru can send messages to mobile as sms, to Viber, and to VK.com profile. So you can set route of a message as 'sms', 'viber', 'vk' or 'viber,sms'. By default - 'sms'.

You can manage different Viber, VK, sms parameters with additional arguments like '_validity', '_sms.validity', '_vk.validity', '_viber.validity', '_viber.btnText', '_viber.btnUrl'...

    # Create a new sender using this driver. Try to send to Viber first.
    my $api = SMS::Send->new('RedSMS2',
        _login    => 'your login',
        _api => 'your api key',
        _from => 'your approved sender name',
        _route => 'viber,sms',
        '_viber.validity' => 3600,
        '_sms.validity' => 86400
    );

Please refer RedSMS.ru API docs for more information.

=item _timeout

The timeout in seconds for HTTP operations. Defaults to 10 seconds.

=back

=head2 send_sms

This method is actually called by L<SMS::Send> when you call send_sms on it.

    my $sent = $api->send_sms(
        'to'             => '+70001234567',
        'text'           => 'This is a test message'
    );

Returns 1 if success, 0 otherwise.

Error text is stored in $@ variable.

=head2 status

Get delivery statuses of sent messages. You should pass into at least one sms-id (uuid) code.

    $status = $api->status('0794e72e-9b64-43bf-ba80-83c74a1ba096','9044f5aa-292b-4c4a-bd7d-17ecd211a54b');
    print $status->{'0794e72e-9b64-43bf-ba80-83c74a1ba096'}; # 1 if delivered, 0 otherwise
    print $status->{'9044f5aa-292b-4c4a-bd7d-17ecd211a54b'};

Sms-id (uuid) code of last sent sms can be gained through 'result' hashref after sending:

    print $api->{OBJECT}->{result}->{response}->{items}->[0]->{uuid};

=head2 info

Get extended data about sent messages:

    print $api->info(filter_name_1 => 'filter_data', filter_name_2 => 'filter_data',...);

Where filter_name should be: uuid, type, source, from, status, to, dispatchId, dispatchSectionId, createdAtFrom, createdAtTo, limit, offset, page, fields.

You can paginate results with limit, offset, page parameters. 'fields' param points to a list of required data columns. It should contain a comma-separated array. By default - 'all'.

Please refer RedSMS.ru API docs for more information.

=head2 balance

Get your balance in rubles.

    print $api->balance();

=head1 BUGS AND LIMITATIONS

The driver is intended only for sending messages. It cannot work with other RedSMS API methods (sender name creating, file uploading, etc.).

=head1 AUTHOR

Ivan Artamonov, <ivan.s.artamonov {at} gmail.com>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut

1;