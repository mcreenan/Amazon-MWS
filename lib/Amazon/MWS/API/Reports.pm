package Amazon::MWS::API::Reports;
use Moose;
extends 'Amazon::MWS::API::Base';

use Amazon::MWS::TypeMap qw(:all);
use DateTime;

sub get_base_parameters {
    my ( $self, $method_name ) = @_;
    return (
        Action           => $method_name,
        AWSAccessKeyId   => $self->access_key_id,
        SellerId         => $self->merchant_id,
        Marketplace      => $self->marketplace_id,
        Version          => '2009-01-01',
        SignatureVersion => 2,
        SignatureMethod  => 'HmacSHA1',
        Timestamp        => to_amazon( 'datetime', DateTime->now ),
    );
}

sub convert_FeedSubmissionInfo {
    my $self = shift;
    my $root = shift;
    $self->force_array( $root, 'FeedSubmissionInfo' );

    foreach my $info ( @{ $root->{FeedSubmissionInfo} } ) {
        $self->convert( $info, SubmittedDate => 'datetime' );
    }
    return;
}

sub convert_ReportRequestInfo {
    my $self = shift;
    my $root = shift;
    $self->force_array( $root, 'ReportRequestInfo' );

    foreach my $info ( @{ $root->{ReportRequestInfo} } ) {
        $self->convert( $info, StartDate     => 'datetime' );
        $self->convert( $info, EndDate       => 'datetime' );
        $self->convert( $info, Scheduled     => 'boolean' );
        $self->convert( $info, SubmittedDate => 'datetime' );
    }
    return;
}

sub convert_ReportInfo {
    my $self = shift;
    my $root = shift;
    $self->force_array( $root, 'ReportInfo' );

    foreach my $info ( @{ $root->{ReportInfo} } ) {
        $self->convert( $info, AvailableDate => 'datetime' );
        $self->convert( $info, Acknowledged  => 'boolean' );
    }
    return;
}

sub convert_ReportSchedule {
    my $self = shift;
    my $root = shift;
    $self->force_array( $root, 'ReportSchedule' );

    foreach my $info ( @{ $root->{ReportSchedule} } ) {
        $self->convert( $info, ScheduledDate => 'datetime' );
    }
    return;
}

sub SubmitFeed {
    my $self = shift;
    return $self->call_api_method(
        method     => 'SubmitFeed',
        args       => @_,
        parameters => {
            FeedContent => {
                required => 1,
                type     => 'HTTP-BODY',
            },
            FeedType => {
                required => 1,
                type     => 'string',
            },
            PurgeAndReplace => { type => 'boolean', },
        },
        respond => sub {
            my $root = shift->{FeedSubmissionInfo};
            $self->convert( $root, SubmittedDate => 'datetime' );
            return $root;
        }
    );
}

=ignore

define_api_method GetFeedSubmissionList =>
    parameters => {
        FeedSubmissionIdList     => { type => 'IdList' },
        MaxCount                 => { type => 'nonNegativeInteger' },
        FeedTypeList             => { type => 'TypeList' },
        FeedProcessingStatusList => { type => 'StatusList' },
        SubmittedFromDate        => { type => 'datetime' },
        SubmittedToDate          => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_FeedSubmissionInfo($root);
        return $root;
    };

define_api_method GetFeedSubmissionListByNextToken =>
    parameters => { 
        NextToken => {
            type     => 'string',
            required => 1,
        },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_FeedSubmissionInfo($root);

        return $root;
    };

define_api_method GetFeedSubmissionCount =>
    parameters => {
        FeedTypeList             => { type => 'TypeList' },
        FeedProcessingStatusList => { type => 'StatusList' },
        SubmittedFromDate        => { type => 'datetime' },
        SubmittedToDate          => { type => 'datetime' },
    },
    respond => sub { $_[0]->{Count} };

define_api_method CancelFeedSubmissions =>
    parameters => {
        FeedSubmissionIdList => { type => 'IdList' },
        FeedTypeList         => { type => 'TypeList' },
        SubmittedFromDate    => { type => 'datetime' },
        SubmittedToDate      => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
        convert_FeedSubmissionInfo($root);
        return $root;
    };

define_api_method GetFeedSubmissionResult =>
    raw_body   => 1,
    parameters => {
        FeedSubmissionId => { 
            type     => 'string',
            required => 1,
        },
    };
=cut

sub RequestReport {
    my ( $self, @args ) = @_;
    return $self->call_api_method(
        method     => 'RequestReport',
        args       => @args,
        parameters => {
            ReportType => {
                type     => 'string',
                required => 1,
            },
            StartDate => { type => 'datetime' },
            EndDate   => { type => 'datetime' },
        },
        respond => sub {
            my $root = shift;
            convert_ReportRequestInfo($root);
            return $root;
        }
    );
}

=ignore
define_api_method GetReportRequestList =>
    parameters => {
        ReportRequestIdList        => { type => 'IdList' },
        ReportTypeList             => { type => 'TypeList' },
        ReportProcessingStatusList => { type => 'StatusList' },
        MaxCount                   => { type => 'nonNegativeInteger' },
        RequestedFromDate          => { type => 'datetime' },
        RequestedToDate            => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_ReportRequestInfo($root);
        return $root;
    };

define_api_method GetReportRequestListByNextToken =>
    parameters => {
        NextToken => { 
            required => 1,
            type      => 'string',
        },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_ReportRequestInfo($root);
        return $root;
    };

define_api_method GetReportRequestCount =>
    parameters => {
        ReportTypeList             => { type => 'TypeList' },
        ReportProcessingStatusList => { type => 'StatusList' },
        RequestedFromDate          => { type => 'datetime' },
        RequestedToDate            => { type => 'datetime' },
    },
    respond => sub { $_[0]->{Count} };

define_api_method CancelReportRequests =>
    parameters => {
        ReportRequestIdList        => { type => 'IdList' },
        ReportTypeList             => { type => 'TypeList' },
        ReportProcessingStatusList => { type => 'StatusList' },
        RequestedFromDate          => { type => 'datetime' },
        RequestedToDate            => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
        convert_ReportRequestInfo($root);
        return $root;
    };

define_api_method GetReportList =>
    parameters => {
        MaxCount            => { type => 'nonNegativeInteger' },
        ReportTypeList      => { type => 'TypeList' },
        Acknowledged        => { type => 'boolean' },
        AvailableFromDate   => { type => 'datetime' },
        AvailableToDate     => { type => 'datetime' },
        ReportRequestIdList => { type => 'IdList' },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_ReportInfo($root);
        return $root;
    };

define_api_method GetReportListByNextToken =>
    parameters => {
        NextToken => {
            type     => 'string',
            required => 1,
        },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_ReportInfo($root);
        return $root;
    };

define_api_method GetReportCount =>
    parameters => {
        ReportTypeList      => { type => 'TypeList' },
        Acknowledged        => { type => 'boolean' },
        AvailableFromDate   => { type => 'datetime' },
        AvailableToDate     => { type => 'datetime' },
    },
    respond => sub { $_[0]->{Count} };

define_api_method GetReport =>
    raw_body   => 1,
    parameters => {
        ReportId => {
            type     => 'nonNegativeInteger',
            required => 1,
        }
    };

define_api_method ManageReportSchedule =>
    parameters => {
        ReportType    => { type => 'string' },
        Schedule      => { type => 'string' },
        ScheduledDate => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
sub SubmitFeed {
    my $self = shift;
    $self->call_api_method(
        method => 'SubmitFeed',
        args => @_,
        parameters => {
            FeedContent => {
                required => 1,
                type     => 'HTTP-BODY',
            },
            FeedType => {
                required => 1,
                type     => 'string',
            },
            PurgeAndReplace => {
                type     => 'boolean',
            },
        },
        respond => sub {
            my $root = shift->{FeedSubmissionInfo};
            $self->convert($root, SubmittedDate => 'datetime');
            return $root;
        });
}
        $self->convert($root, ScheduledDate => 'datetime');
        return $root;
    };

define_api_method GetReportScheduleList =>
    parameters => {
        ReportTypeList => { type => 'ReportType' },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_ReportSchedule($root);
        return $root;
    };

define_api_method GetReportScheduleListByNextToken =>
    parameters => {
        NextToken => {
            type     => 'string',
            required => 1,
        },
    },
    respond => sub {
        my $root = shift;
        $self->convert($root, HasNext => 'boolean');
        convert_ReportSchedule($root);
        return $root;
    };

define_api_method GetReportScheduleCount =>
    parameters => {
        ReportTypeList => { type => 'ReportType' },
    },
    respond => sub { $_[0]->{Count} };

define_api_method UpdateReportAcknowledgements =>
    parameters => {
        ReportIdList => { 
            type     => 'IdList',
            required => 1,
        },
        Acknowledged => { type => 'boolean' },
    },
    respond => sub {
        my $root = shift;
        convert_ReportInfo($root);
        return $root;
    };

=cut

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Amazon::MWS::API::Reports

=head1 DESCRIPTION

API bindings for Amazon's MWS Reports API

=head1 METHODS

=head2 new

Constructs a new client object.  Takes the following keyword arguments:

=head3 agent_attributes

An attributes you would like to add (besides language=Perl) to the user agent
string, as a hashref.

=head3 application

The name of your application.  Defaults to 'Amazon::MWS::Client'

=head3 version

The version of your application.  Defaults to the current version of this
module.

=head3 endpoint

Where MWS lives.  Defaults to 'https://mws.amazonaws.com/'.

=head3 access_key_id

Your AWS Access Key Id

=head3 secret_key

Your AWS Secret Access Key

=head3 merchant_id

Your Amazon Merchant ID

=head3 marketplace_id

The marketplace id for the calls being made by this object.

=head1 EXCEPTIONS

Any of the L<API METHODS> can throw the following exceptions
(Exception::Class).  They are all subclasses of Amazon::MWS::Exception.

=head2 Amazon::MWS::Exception::MissingArgument

The call to the API method was missing a required argument.  The name of the
missing argument can be found in $e->name.

=head2 Amazon::MWS::Exception::Transport

There was an error communicating with the Amazon endpoint.  The HTTP::Request
and Response objects can be found in $e->request and $e->response.

=head2 Amazon::MWS::Exception::Response

Amazon returned an response, but indicated an error.  An arrayref of hashrefs
corresponding to the error xml (via XML::Simple on the Error elements) is
available at $e->errors, and the entire xml response is available at $e->xml.

=head2 Amazon::MWS::Exception::BadChecksum

If Amazon sends the 'Content-MD5' header and it does not match the content,
this exception will be thrown.  The response can be found in $e->response.

=head1 API METHODS

The following methods may be called on objects of this class.  All concerns
(such as authentication) which are common to every request are handled by this
class.  

Enumerated values may be specified as strings or as constants from the
Amazon::MWS::Enumeration packages for compile time checking.  

All parameters to individual API methods may be specified either as name-value
pairs in the argument string or as hashrefs, and should have the same names as
specified in the API documentation.  

Return values will be hashrefs with keys as specified in the 'Response
Elements' section of the API documentation unless otherwise noted.

The mapping of API datatypes to perl datatypes is specified in
L<Amazon::MWS::TypeMap>.  Note that where the documentation calls for a
'structured list', you should pass in an arrayref.

=head2 SubmitFeed

Requires an additional 'content_type' argument specifying what content type
the HTTP-BODY is.

=head2 GetFeedSubmissionList

=head2 GetFeedSubmissionListByNextToken

=head2 GetFeedSubmissionCount

Returns the count as a simple scalar (as do all methods ending with Count)

=head2 CancelFeedSubmissions

=head2 GetFeedSubmissionResult

The raw body of the response is returned.

=head2 RequestReport

The returned ReportRequest will be an arrayref for consistency with other
methods, even though there will only ever be one element.

=head2 GetReportRequestList

=head2 GetReportRequestListByNextToken

=head2 GetReportRequestCount

=head2 CancelReportRequests

=head2 GetReportList

=head2 GetReportListByNextToken

=head2 GetReportCount

=head2 GetReport

The raw body is returned.

=head2 ManageReportSchedule

=head2 GetReportScheduleList

=head2 GetReportScheduleListByNextToken

=head2 GetReportScheduleCount

=head2 UpdateReportAcknowledgements

=head1 AUTHOR

Paul Driver C<< frodwith@cpan.org >>

Matt Creenan C<< mattcreenan@gmail.com >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Plain Black Corporation L<http://plainblack.com>.
All rights reserved

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.  See L<perlartistic>.
