package Tilt::TwitterApp;
use strict;
use Dancer ':syntax';
use Tilt::TwitterAPI;
use Tilt::TwitterCache;

our $VERSION = '0.1';
our $twitter_api;

hook 'before' => sub {

    # Twitter API authentication
    config->{twitter_api} = {
        consumer_key => $ENV{TAPI_CONSUMER_KEY},
        consumer_secret => $ENV{TAPI_CONSUMER_SECRET},
        token => $ENV{TAPI_TOKEN},
        token_secret => $ENV{TAPI_TOKEN_SECRET},
    };

};

get '/' => sub {
    template 'index';
};

any [ 'get', 'post' ] => '/user_recent_tweets' => sub {

    my $q = request->params;
    my $show_tweets = 0;
    my $error = '';
    my $recent_tweets = [];
    if ( $q->{commit} ) {
        
        # check cache
        my $tc = Tilt::TwitterCache->new(config->{memcached});
        unless ($tc->{error}) { 
            $recent_tweets = $tc->get_recent_user_tweets($q->{username}) || [];
        }
      
        if  ($recent_tweets && @{$recent_tweets}) {
            $show_tweets = 1;
        } else {
            my $twitter = Tilt::TwitterAPI->new(config->{twitter_api});
            if ($twitter->{error}) {
                $error = 'Could not connect to Twitter API';
            } else {
                $recent_tweets = $twitter->get_recent_user_tweets($q->{username}) || [];
                if ($twitter->{error}) {
                    $error = _get_error_text($twitter->{error});
                } else {
                    $show_tweets = 1;
                    unless ($tc->{error}) {
                        $tc->set_recent_user_tweets($q->{username}, $recent_tweets);
                    }
                }
            }
        }

    }


    template 'user_recent_tweets' => {
        username => $q->{username},
        show_tweets => $show_tweets,
        error => $error,
        recent_tweets => $recent_tweets,
        tweet_count => scalar @{$recent_tweets},
    };

};

any [ 'get', 'post' ] => '/shared_following' => sub {

    my $q = request->params;
    my $show_following = 0;
    my $error = '';
    my $shared_following = [];
    my $total_pages = 0;

    if ( $q->{commit} ) {
        # check cache
        my $page = $q->{page} || 1;
        my $maxrecs = config->{twitterapp}{shared_following}{results_per_page};
        my $tc = Tilt::TwitterCache->new(config->{memcached});
        unless ($tc->{error}) { # log and continue on cache errors
            my $val = $tc->get_shared_following({
                usernames => [$q->{username1},$q->{username2}],
                page => $page,
            }) || [];
            unless ($tc->{error}) {
                $shared_following = $val->{sf} if $val->{sf};
                $total_pages = $val->{tp} if $val->{tp};
            }
        }
      
        if  ($shared_following && @{$shared_following}) {
            $show_following = 1;
        } else {
            my $twitter = Tilt::TwitterAPI->new(config->{twitter_api});
            if ($twitter->{error}) {
                $error = _get_error_text($twitter->{error});
            } else {
                my ($usf, $cnt) = $twitter->get_shared_following({
                    usernames => [$q->{username1},$q->{username2}],
                    offset => ($page - 1) * $maxrecs,
                    maxrecs => $maxrecs,
                    tc => $tc,
                });
                if ($twitter->{error}) {
                    $error = _get_error_text($twitter->{error});
                } else {
                    $show_following = 1;
                    $shared_following = $usf;
                    $total_pages = int($cnt / $maxrecs) + 1;
                    $tc->set_shared_following({
                        usernames => [$q->{username1},$q->{username2}],
                        page => $page,
                        shared_following => $shared_following,
                        total_pages => $total_pages,
                    });
                }
            }
        }
    }

    my @pagelist = (1);
    push @pagelist, (2..$total_pages) if $total_pages > 1; 

    template 'shared_following' => {
        username1 => $q->{username1},
        username2 => $q->{username2},
        show_following => $show_following,
        error => $error,
        shared_following => $shared_following,
        following_count => scalar @{$shared_following},
        total_pages => $total_pages,
        page  => $q->{page},
        pagelist => \@pagelist,
    };

};


#
# Numeric error codes (TAPI_ERROR_ prefix originate from twitter, others 
# from this app
# Memcache errors not included as they are not displayed in the view
#
sub _get_error_text {

    my ($error) = @_;

    return "Unknown error, please try again" unless $error;

    
    my %errors = (
        TAPI_ERROR_32             => "Twitter API authentication failed",
        TAPI_ERROR_215            => "Twitter API authentication failed",
        TAPI_ERROR_34             => "This username does not exist on Twitter",
        TAPI_ERROR_88             => "Rate limit temporarily excceeded. Please try again later",
        USERNAME_OMITTED          => "Username is a required field",
        USERNAME_TOO_LONG         => "Username is a too long",
        USERNAME_INVALID_CHARS    => "Username may only contain alphanumeric characters and underscores",
        USERNAME_TWO_REQUIRED     => "You must enter two usernames",
        OFFSET_OUT_OF_BOUNDS      => "Page selection out of bounds",
        TAPI_CREATE_ERROR         => "Problem connecting to Twitter API",
    );

    return "Unknown error, please try again" unless $errors{$error};
    return $errors{$error};

}

true;
