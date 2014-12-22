use strict;

use Net::Twitter;
#use Net::Twitter::Lite;
use Data::Dumper;
use URI::Encode qw(uri_encode uri_decode);

my $consumer_key = '5AHVaGA493FIyz96SxCiS7vhC';
my $consumer_secret = 'ohQxXPbHsfT2DgW8rooV2VwGZzFuocK7GjGhIiS47ZD4wAczmX';
my $token = '60664044-zEh07ay9GLkYtfjgHNQz4ApyO6vfuQ3LeLoRXEfo7';
my $token_secret = 'XSKhLwLVYapcVDDFZXwZdx2oAJSpB7HfiXyrBhvIbZ1PE';

my $twitter = Net::Twitter->new(
    traits => ["API::RESTv1_1"],
    consumer_key        => $consumer_key,
    consumer_secret     => $consumer_secret,
    access_token        => $token,
    access_token_secret => $token_secret,
);

=com
my $twitter = Net::Twitter::Lite->new(
    legacy_lists_api => 0,
    apiurl => 'http://api.twitter.com/1.1'
);


#my $blah = $twitter->search("from:poisonspur&page=1&count=3");
#my $blah = $twitter->search( "from:poisonspur", count => 5 );
for my $status ( @{$blah->{results}} ) {
    print "$status->{text}\n";
}
=cut

#my $blah = $twitter->lookup_users( { screen_name => ['poisonspur'] });
my $blah = $twitter->user_timeline( { screen_name => ['pattonoswalt'] });
for my $status ( @{$blah} ) {
    print "$status->{text}\n";
}

#print Dumper $blah->{results};
#print Dumper $blah;


