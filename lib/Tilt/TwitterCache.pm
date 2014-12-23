package Tilt::TwitterCache;

use strict;

use Cache::Memcached;
use Tilt::TwitterAPI;
use Dancer::Logger::Console;


sub new {

    my ($class, $params) = @_;

    my $self = {
        error => '',
        ttl => $params->{ttl},
    };

    $self->{logger} = Dancer::Logger::Console->new();

    my @servers = split /\,/, $params->{servers};

    $self->{mc}= Cache::Memcached->new(
        servers => \@servers,
    ); 
    if ($@ || !$self->{mc}) {
        $self->{error} = "MCD_CREATE_ERROR";
        $self->{logger}->error("$self->{error}|$@");

    }

    bless $self, $class;

    return $self;

}

#
# Gets a user's recent tweets
#
sub get_recent_user_tweets {

    my ($self, $username) = @_;

    if ($self->{error} = Tilt::TwitterAPI::check_bad_username($username)) {
        $self->{logger}->error("$self->{error}");
        return undef;
    }

    my $key = "rt|$username";

    my $rt = eval { $self->{mc}->get($key) };
    if ($@) {
        $self->{error} = "ERROR_GETTING_TWEETS";
        $self->{logger}->error("$self->{error}|$@");
        return undef;
    }

    return $rt;

}


#
# Sets the user's recent tweets. If there are no recent tweets, delete the 
# memcache entry
#
sub set_recent_user_tweets {

    my ($self, $username, $recent_tweets) = @_;

    if ($self->{error} = Tilt::TwitterAPI::check_bad_username($username)) {
        $self->{logger}->error($self->{error});
        return undef;
    }

    my $key = "rt|$username";

    if ($recent_tweets && @{$recent_tweets} ) {
        eval { $self->{mc}->set($key, $recent_tweets, $self->{tty}{tweet}) };
        if ($@) {
             $self->{error} = "ERROR_SETTING_TWEETS";
             $self->{logger}->error("$self->{error}|$@");
             return undef;
        }
    } else {
        eval { $self->{mc}->delete($key) };
        if ($@) {
             $self->{error} = "ERROR_DELETING_TWEET_ENTRY";
             $self->{logger}->error("$self->{error}|$@");
             return undef;
        }
    }

}

#
# get shared following for two users
#
sub get_shared_following {

    my ($self, $params) = @_;

    my $usernames = $params->{usernames};
    my $shared_following = $params->{shared_following};
    my $page = $params->{page} || 1;

    # check for two usernames
    if ( $#{$usernames} != 1) {
        $self->{error} = "USERNAME_TWO_REQUIRED";
        $self->{logger}->error($self->{error});
        return undef;
    }

    # error check for each username
    foreach my $username (@{$usernames}) {
        if ($self->{error} = Tilt::TwitterAPI::check_bad_username($username)) {
            $self->{logger}->error($self->{error});
            return undef;
        }
    }

    # sort usernames so key will be the same regardless of order entered
    my $sorted_unames = join '|', sort { $a cmp $b } @{$usernames};
    my $key = "sf|$sorted_unames|$page";

    my $val = eval { $self->{mc}->get($key) } || {};
    if ($@) {
         $self->{error} = "ERROR_GETTING_SHARED_FOLLOWING";
         $self->{logger}->error("$self->{error}|$@");
         return undef;
    }

    return $val;

}

#
# Sets the users' shared tweets. If there are none, delete the 
# memcache entry
#
sub set_shared_following {

    my ($self, $params) = @_;

    my $usernames = $params->{usernames};
    my $page = $params->{page} || 1;
    my $shared_following = $params->{shared_following};
    my $total_pages = $params->{total_pages} || 1;

    # check for two usernames
    if ( $#{$usernames} != 1) {
        $self->{error} = "USERNAME_TWO_REQUIRED";
        $self->{logger}->error($self->{error});
        return undef;
    }

    # error check for each username
    foreach my $username (@{$usernames}) {
        if ($self->{error} = Tilt::TwitterAPI::check_bad_username($username)) {
            $self->{logger}->error($self->{error});
            return undef;
        }
    }

    # sort usernames so key will be the same regardless of order entered
    my $sorted_unames = join '|', sort { $a cmp $b } @{$usernames};
    my $key = "sf|$sorted_unames|$page";


    if ($shared_following && @{$shared_following} ) {
        my $val = {
            sf => $shared_following,
            tp => $total_pages,
        };
        eval { $self->{mc}->set($key, $val, $self->{tty}{user}) };
        if ($@) {
            $self->{error} = "ERROR_SETTING_FOLLOWING";
            $self->{logger}->error("$self->{error}|$@");
            return undef;
        }
    } else {
        eval { $self->{mc}->delete($key) };
        if ($@) {
            $self->{error} = "ERROR_DELETING_FOLLOWING_ENTRY";
            $self->{logger}->error("$self->{error}|$@");
            return undef;
        }
    }

}

sub get_following_ids {

    my ($self, $username) = @_;

    if ($self->{error} = Tilt::TwitterAPI::check_bad_username($username)) {
        $self->{logger}->error($self->{error});
        return undef;
    }


    my $key = "fid|$username";

    my $fid = eval { $self->{mc}->get($key) };
    if ($@) {
        $self->{error} = "ERROR_GETTING_FOLLOWING_IDS";
        $self->{logger}->error("$self->{error}|$@");
        return undef;
    }

    return $fid;

}

sub set_following_ids {

    my ($self, $username, $following_ids) = @_;

    if ($self->{error} = Tilt::TwitterAPI::check_bad_username($username)) {
        $self->{logger}->error("$self->{error}");
        return undef;
    }

    my $key = "fid|$username";


    if ($following_ids && @{$following_ids} ) {
        eval { $self->{mc}->set($key, $following_ids, $self->{tty}{user}) };
        if ($@) {
             $self->{error} = "ERROR_SETTING_FOLLOWING_IDS";
             $self->{logger}->error("$self->{error}|$@");
             return undef;
        }
    } else {
        eval { $self->{mc}->delete($key) };
        if ($@) {
             $self->{error} = "ERROR_DELETING_FOLLOWING_IDS";
             $self->{logger}->error("$self->{error}|$@");
             return undef;
        }
    }

}
1;
