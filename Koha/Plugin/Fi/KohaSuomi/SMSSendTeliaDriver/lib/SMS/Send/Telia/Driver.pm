package SMS::Send::Telia::Driver;
#use Modern::Perl; #Can't use this since SMS::Send uses hash keys starting with _
use SMS::Send::Driver ();
use LWP::Simple;
use URI::Escape;
use Koha::Notice::Messages;
use Koha::Libraries;
use Encode;

use Try::Tiny;

use vars qw{$VERSION @ISA};
BEGIN {
        $VERSION = '0.01';
        @ISA     = 'SMS::Send::Driver';
}


#####################################################################
# Constructor

sub new {
        my $class = shift;
        my $params = {@_};

        my $username = $params->{_login} ? $params->{_login} : $params->{_user};
        my $password = $params->{_password} ? $params->{_password} : $params->{_passwd};
        my $baseUrl = $params->{_baseUrl};

        if (! defined $username ) {
            warn "->send_sms(_login) must be defined!";
            return;
        }
        if (! defined $password ) {
            warn "->send_sms(_password) must be defined!";
            return;
        }

        if (! defined $baseUrl ) {
            warn "->send_sms(_baseUrl) must be defined!";
            return;
        }

        #Prevent injection attack
        $self->{_login} =~ s/'//g;
        $self->{_password} =~ s/'//g;

        # Create the object
        my $self = bless {}, $class;

        $self->{_login} = $username;
        $self->{_password} = $password;
        $self->{_baseUrl} = $baseUrl;
        $self->{_sourceName} = $params->{_sourceName};
        $self->{_clientId} = $params->{_clientId};

        return $self;
}

sub _get_telia_clientId {
    my ($config, $message_id) = @_;
    my $clientid;

    if (ref($config) eq "HASH") {
        my $notice = Koha::Notice::Messages->find($message_id);
        my $library = Koha::Libraries->find({branchemail => $notice->{from_address}});
        my %clientIds = %{$config};
        foreach $key (keys %clientIds) {
            if ($key eq $library->branchcode) {
                $clientid = $clientIds{$key};
                last;
            }
        }
    } else {
        $clientid = $config;
    }
    return $clientid;
}

sub send_sms {
    my $self    = shift;
    my $params = {@_};
    my $message = $params->{text};
    my $recipientNumber = $params->{to};

    my $clientid = _get_telia_clientId($self->{_clientId}, $params->{_message_id});;

    if (! defined $message ) {
        warn "->send_sms(text) must be defined!";
        return;
    }
    if (! defined $recipientNumber ) {
        warn "->send_sms(to) must be defined!";
        return;
    }
    if (! defined $clientid) {
        warn "->send_sms(clientid) must be defined!";
        return;
    }

    #Clean recipientnumber
    $recipientNumber =~ s/^\+//;
    $recipientNumber =~ s/^0/358/;
    $recipientNumber =~ s/\-//;
    $recipientNumber =~ s/ //;
    #Prevent injection attack!
    $recipientNumber =~ s/'//g;
    $message =~ s/(")|(\$\()|(`)/\\"/g; #Sanitate " so it won't break the system( iconv'ed curl command )

    my $base_url = $self->{_baseUrl};
    my $parameters = {
        'U'   => $self->{_login},
        'P'   => $self->{_password},
        'T'   => $recipientNumber,
        'M'   => Encode::encode( "iso-8859-1", $message)
    };

    if ($clientid) {
        $parameters->{'C'} = $clientid;
    }

    if ($self->{_sourceName}) {
        $parameters->{'F'} = $self->{_sourceName};
    }

    $parameters->{'M'} = uri_escape($parameters->{'M'});
    $parameters->{'P'} = uri_escape($parameters->{'P'});

    my $get_request = '?U='.$parameters->{'U'}.'&P='.$parameters->{'P'}.'&F='.$parameters->{'F'}.'&T='.$parameters->{'T'}.'&M='.$parameters->{'M'};

    my $return = get($base_url.$get_request);

    my $delivery_note = $return;

    return 1 if ($return =~ m/to+/);

    # remove everything except the delivery note
    $delivery_note =~ s/^(.*)message\sfailed:\s*//g;

    # pass on the error by throwing an exception - it will be eventually caught
    # in C4::Letters::_send_message_by_sms()
    die $delivery_note;
}
1;
