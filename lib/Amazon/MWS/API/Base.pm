package Amazon::MWS::API::Base;
use Moose;

use URI;
use Readonly;
use DateTime;
use XML::Simple;
use URI::Escape;
use MIME::Base64;
use Digest::HMAC_SHA1 qw(hmac_sha1);
use HTTP::Request;
use LWP::UserAgent;
use Digest::MD5 qw(md5_base64);
use Amazon::MWS::TypeMap qw(:all);

my $baseEx;
BEGIN { Readonly $baseEx => 'Amazon::MWS::Client::Exception' }

use Exception::Class (
    $baseEx,
    "${baseEx}::MissingArgument" => {
        isa    => $baseEx,
        fields => 'name',
        alias  => 'arg_missing',
    },
    "${baseEx}::Transport" => {
        isa    => $baseEx,
        fields => [qw(request response)],
        alias  => 'transport_error',
    },
    "${baseEx}::Response" => {
        isa    => $baseEx,
        fields => [qw(errors xml)],
        alias  => 'error_response',
    },
    "${baseEx}::BadChecksum" => {
        isa    => $baseEx,
        fields => 'request',
        alias  => 'bad_checksum',
    },
    "${baseEx}::InvalidApiImplementation" => {
        isa    => $baseEx,
        fields => 'class',
        alias  => 'invalid_api_implementation',
    },
);

has [ 'access_key_id', 'secret_key', 'merchant_id', 'marketplace_id' ] =>
  ( is => 'ro', isa => 'Str', required => 1 );
has 'client_application' =>
  ( is => 'ro', isa => 'Str', default => 'Amazon::MWS::API' );
has 'client_version' => ( is => 'ro', isa => 'Str', default => '0.1.0' );
has 'agent_attributes' => ( is => 'ro', isa => 'HashRef' );
has 'endpoint' =>
  ( is => 'ro', isa => 'Str', default => 'https://mws.amazonaws.com/' );
has 'agent' => (
    is      => 'ro',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;

        my $attr = $self->agent_attributes;
        $attr->{Language} = 'Perl';
        my $attr_str = join ';', map { "$_=$attr->{$_}" } keys %$attr;

        return LWP::UserAgent->new( agent => $self->client_application . '/'
              . $self->client_version
              . " ($attr_str)" );
    }
);

sub force_array {
    my ( $self, $hash, $key ) = @_;
    my $val = $hash->{$key};

    if ( !defined $val ) {
        $val = [];
    }
    elsif ( ref $val ne 'ARRAY' ) {
        $val = [$val];
    }

    $hash->{$key} = $val;
}

sub convert {
    my ( $hash, $key, $type ) = @_;
    return $hash->{$key} = from_amazon( $type, $hash->{$key} );
}

sub slurp_kwargs {
    return ref $_[0] eq 'HASH' ? shift : {@_};
}

sub get_base_parameters {
    my ($self) = @_;
    invalid_api_implemtation $self;
    return;
}

sub sign_request {
    my ( $self, $request ) = @_;
    my $uri       = $request->uri;
    my %params    = $uri->query_form;
    my $canonical = join '&',
      map { uri_escape($_) . '=' . uri_escape( $params{$_} ) }
      sort keys %params;

    my $string =
        $request->method . "\n"
      . $uri->authority . "\n"
      . $uri->path . "\n"
      . $canonical;

    $params{Signature} =
      encode_base64( hmac_sha1( $string, $self->secret_key ), '' );
    $uri->query_form( \%params );
    return $request->uri($uri);
}

sub call_api_method {
    my $self        = shift;
    my $spec        = slurp_kwargs(@_);
    my $method_name = $spec->{method};
    my $params      = slurp_kwargs( $spec->{parameter_spec} );
    my $args        = $spec->{with_args};
    my $body;

    my %form = $self->get_base_parameters($method_name);
    foreach my $name ( keys %$params ) {
        my $param = $params->{$name};

        unless ( exists $args->{$name} ) {
            arg_missing( name => $name ) if $param->{required};
            next;
        }

        my $type  = $param->{type};
        my $value = $args->{$name};

        # Odd 'structured list' notation handled here
        if ( $type =~ /(\w+)List/x ) {
            my $list_type = $1;
            my $counter   = 1;
            foreach my $sub_value (@$value) {
                my $listKey = "$name.$list_type." . $counter++;
                $form{$listKey} = $sub_value;
            }
            next;
        }

        if ( $type eq 'HTTP-BODY' ) {
            $body = $value;
        }
        else {
            $form{$name} = to_amazon( $type, $value );
        }
    }

    my $uri = URI->new( $self->endpoint );
    $uri->query_form( \%form );

    my $request = HTTP::Request->new;
    $request->uri($uri);

    if ($body) {
        $request->method('POST');
        $request->content($body);
        $request->header( 'Content-MD5' => md5_base64($body) . '==' );
        $request->content_type( $args->{content_type} );
    }
    else {
        $request->method('GET');
    }

    $self->sign_request($request);
    my $response = $self->agent->request($request);
    my $content  = $response->content;

    my $xs = XML::Simple->new( KeepRoot => 1 );

    if ( $response->code == 400 || $response->code == 403 ) {
        my $hash = $xs->xml_in($content);
        my $root = $hash->{ErrorResponse};
        $self->force_array( $root, 'Error' );
        error_response( errors => $root->{Error}, xml => $content );
    }

    unless ( $response->is_success ) {
        transport_error( request => $request, response => $response );
    }

    if ( my $md5 = $response->header('Content-MD5') ) {
        bad_checksum( response => $response )
          unless ( $md5 eq md5_base64($content) . '==' );
    }

    return $content if $spec->{raw_body};

    my $hash = $xs->xml_in($content);

    my $root =
      $hash->{ $method_name . 'Response' }->{ $method_name . 'Result' };

    return $spec->{filter_response}->($root);
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Amazon::MWS::Client

=head1 DESCRIPTION

An API binding for Amazon's Marketplace Web Services.  An overview of the
entire interface can be found at L<https://mws.amazon.com/docs/devGuide>.

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
