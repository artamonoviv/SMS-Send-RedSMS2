requires "Digest::MD5"      => "2.55";
requires "JSON::MaybeXS"    => "1.003008";
requires "URI::Escape"      => "3.31";
requires "SMS::Send"        => "1.06";

on 'test' => sub {
    requires 'Test::More', '0.98';
};

