package Tilt::TwitterAPI;

use strict;
use Net::Twitter;
use Dancer::Logger::Console;


#
# Constructs and establishes connection
#
sub new {

    my ($class, $params) = @_;

    my $self = {
        error => '',
    };

    $self->{logger} = Dancer::Logger::Console->new();

    $self->{tw} = Net::Twitter->new(
            traits => ["API::RESTv1_1"],
            consumer_key        => $params->{consumer_key},
            consumer_secret     => $params->{consumer_secret},
            access_token        => $params->{token},
            access_token_secret => $params->{token_secret},
    );
    if ($@ || !$self->{tw}) {
        $self->{error} = "TAPI_CREATE_ERROR";
        $self->{logger}->error("$self->{error}|$@");
    }


    bless $self, $class;

    return $self;

}

#
# Recent tweets for a given username
#
sub get_recent_user_tweets {

    my ($self, $username) = @_;

    my $SUB = 'get_recent_tweets';

    my $recent_tweets = [];

    # error check username
    if ($self->{error} = check_bad_username($username)) {
        $self->{logger}->error($self->{error});
        return undef;
    }

    # username not on twitter results in fatal error so this needs to be
    # wrapped in an eval
    my $user_tweets = eval {
        $self->{tw}->user_timeline( { screen_name => [$username] });
    };
    if (my $err = $@) {
        $self->{error} = "TAPI_ERROR_" . $err->twitter_error_code;
        $self->{logger}->error("$self->{error}|$@");
        return undef;
    }

    foreach my $tweet ( @{$user_tweets} ) {
        push @{$recent_tweets}, {
            text => $tweet->{text},
            created_at => $tweet->{created_at},
            favorite_count => $tweet->{favorite_count},
            retweet_count => $tweet->{retweet_count},
            link => 'https://twitter.com/' . $username . '/status/' . $tweet->{id_str},
            img_url => $tweet->{user}{profile_image_url},

        };
    }

    return $recent_tweets;

}

#
# Return intersecting screen names for whom two users follow
#
sub get_shared_following {

    my ($self, $params) = @_;

    my $SUB = 'get_shared_following';

    my $usernames = $params->{usernames};
    my $offset = $params->{offset} || 0;
    my $maxrecs = $params->{maxrecs} || 100;
    my $tc = $params->{tc};

    my $shared_following = [];
    my $total_shared = 0;

    # check for two usernames
    if ( $#{$usernames} != 1) {
        $self->{error} = "USERNAME_TWO_REQUIRED";
        $self->{logger}->error("$self->{error}");
        return undef;
    }

    # error check for each username
    foreach my $username (@{$usernames}) {
        if ($self->{error} = check_bad_username($username)) {
            $self->{logger}->error("$self->{error}");
            return undef;
        }
    }

    # find following for each username
    my $following = [];
    for (my $i = 0; $i < 2; $i++) {
        push @{$following}, $self->get_following_ids($usernames->[$i], $tc); 
        if ($self->{error}) {
            return undef;
        }
    }

    # Get a list of intersecting user IDs
    my %h0 = map { $_ => 1} @{$following->[0]{ids}};
    my %h1 = map { $_ => 1} @{$following->[1]{ids}}; # in case of dupes (I doubt there are)
    my @intersect_ids = ();
    foreach my $id (sort { $a <=> $b } keys %h1) { # sort needed for pagination
        push @intersect_ids, $id if $h0{$id};
    }

    # Look up their screen names etc
    if (@intersect_ids) {
        $total_shared = scalar @intersect_ids;

        # error if out of bounds
        if ( $offset > $total_shared) {
            $self->{error} = "OFFSET_OUT_OF_BOUNDS";
            $self->{logger}->error("$self->{error}");
            return undef;
        }
        
        # pagination pruning
        if ( (scalar @intersect_ids) > $maxrecs - $offset) {
            @intersect_ids = splice(@intersect_ids,$offset,$maxrecs);
        } else {
            @intersect_ids = splice(@intersect_ids,$offset);
        }

        my $following = eval {
            $self->{tw}->lookup_users(  { user_id => \@intersect_ids } );
        };
        if (my $err = $@) {
            $self->{error} = "TAPI_ERROR_" . $err->twitter_error_code;
            $self->{logger}->error("$self->{error}|$@");
            return undef;
        }
 
        foreach my $user ( @{$following} ) {
            push @{$shared_following}, {
                id => $user->{id},
                name => $user->{name},
                screen_name => $user->{screen_name},
                description => $user->{description},
                friends_count => $user->{friends_count},
                followers_count => $user->{followers_count},
                link => 'http://twitter.com/'. $user->{screen_name},
                img_url => $user->{profile_image_url_https},
            }; 
        }
        
    }

    my @sorted_shared_following = sort { $a->{id} <=> $b->{id} } @{$shared_following};

    return (\@sorted_shared_following, $total_shared);

}

#
# Returns list of user ids that a user follows
#
sub get_following_ids {

    my ($self, $username, $tc) = @_;

    my $following_ids = {};

    my $SUB = 'get_user_following_ids';

    # TODO check memcache

    # error check for each username
    if ($self->{error} = check_bad_username($username)) {
        $self->{logger}->error($self->{error});
        return undef;
    }

    # return list from cache if available
    unless ($tc->{error}) { 
        $following_ids->{ids} = $tc->get_following_ids($username) || [];
        unless ($tc->{error}) {
            if ($following_ids && $following_ids->{ids} && @{$following_ids->{ids}}) {
                return $following_ids;
            }
        }
    }

    $following_ids = eval {
        $self->{tw}->friends_ids(  { screen_name => $username });
    };
    if (my $err = $@) {
        $self->{error} = "TAPI_ERROR_" . $err->twitter_error_code;
        $self->{logger}->error("$self->{error}|$@");
        return undef;
    }

    unless ($tc->{error}) { 
        my $val = $tc->set_following_ids($username, $following_ids->{ids});
    }

    return $following_ids;

}


sub check_bad_username {

    my ($username) = @_;

    return 'USERNAME_OMITTED' unless $username;
    return 'USERNAME_TOO_LONG' if  length($username) > 15;
    return 'USERNAME_INVALID_CHARS' unless $username =~ /^[a-z0-9_]+$/i;
    return '';

}

1;
