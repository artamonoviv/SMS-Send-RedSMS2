# NAME

SMS::Send::RedSMS2 - SMS::Send driver to send messages via RedSMS.ru service (https://redsms.ru) API 2.0

# VERSION

version 0.001

# SYNOPSIS

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

# DESCRIPTION

SMS::Send driver for RedSMS - [https://www.redsms.ru/](https://www.redsms.ru/)

This is not intended to be used directly, but instead called by SMS::Send (see
synopsis above for a basic illustration, and see SMS::Send's documentation for
further information).

The driver uses the RedSMS HTTP API mechanism (cp.redsms.ru version) with JSON.

# METHODS

## new

    # Create a new sender using this driver
    my $api = SMS::Send->new('RedSMS2',
        _login    => 'your login',
        _api => 'your api key',
        _from => 'your approved sender name',
    );

Additional arguments that may be passed include:

- \_endpoints

    A hashref with HTTP API endpoints. Default are:

        _endpoints=>
        {
            send=>'https://cp.redsms.ru/api/message',
            status=>'https://cp.redsms.ru/api/message',
            balance=>'https://cp.redsms.ru/api/client/info'
        }

- \_route

    RedSMS.ru can send messages to mobile as sms, to Viber, and to VK.com profile. So you can set route of a message as 'sms', 'viber', 'vk' or 'viber,sms'. By default - 'sms'.

    You can manage different Viber, VK, sms parameters with additional arguments like '\_validity', '\_sms.validity', '\_vk.validity', '\_viber.validity', '\_viber.btnText', '\_viber.btnUrl'...

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

- \_timeout

    The timeout in seconds for HTTP operations. Defaults to 10 seconds.

## send\_sms

This method is actually called by [SMS::Send](https://metacpan.org/pod/SMS::Send) when you call send\_sms on it.

    my $sent = $api->send_sms(
        'to'             => '+70001234567',
        'text'           => 'This is a test message'
    );

Returns 1 if success, 0 otherwise.

Error text is stored in $@ variable.

## status

Get delivery statuses of sent messages. You should pass into at least one sms-id (uuid) code.

    $status = $api->status('0794e72e-9b64-43bf-ba80-83c74a1ba096','9044f5aa-292b-4c4a-bd7d-17ecd211a54b');
    print $status->{'0794e72e-9b64-43bf-ba80-83c74a1ba096'}; # 1 if delivered, 0 otherwise
    print $status->{'9044f5aa-292b-4c4a-bd7d-17ecd211a54b'};

Sms-id (uuid) code of last sent sms can be gained through 'result' hashref after sending:

    print $api->{OBJECT}->{result}->{response}->{items}->[0]->{uuid};

## info

Get extended data about sent messages:

    print $api->info(filter_name_1 => 'filter_data', filter_name_2 => 'filter_data',...);

Where filter\_name should be: uuid, type, source, from, status, to, dispatchId, dispatchSectionId, createdAtFrom, createdAtTo, limit, offset, page, fields.

You can paginate results with limit, offset, page parameters. 'fields' param points to a list of required data columns. It should contain a comma-separated array. By default - 'all'.

Please refer RedSMS.ru API docs for more information.

## balance

Get your balance in rubles.

    print $api->balance();

# BUGS AND LIMITATIONS

The driver is intended only for sending messages. It cannot work with other RedSMS API methods (sender name creating, file uploading, etc.).

# AUTHOR

Ivan Artamonov, &lt;ivan.s.artamonov {at} gmail.com>

# LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
