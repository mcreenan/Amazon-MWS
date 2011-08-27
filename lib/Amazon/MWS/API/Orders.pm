package Amazon::MWS::API::Orders;
use Moose;
extends 'Amazon::MWS::API::Base';

use Amazon::MWS::TypeMap qw(:all);
use DateTime;

has 'endpoint' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'https://mws.amazonaws.com/Orders/2011-01-01'
);

sub get_base_parameters {
    my ( $self, $method_name ) = @_;
    return (
        'Action'             => $method_name,
        'AWSAccessKeyId'     => $self->access_key_id,
        'SellerId'           => $self->merchant_id,
        'MarketplaceId.Id.1' => $self->marketplace_id,
        'Version'            => '2009-01-01',
        'SignatureVersion'   => 2,
        'SignatureMethod'    => 'HmacSHA1',
        'Timestamp'          => to_amazon( 'datetime', DateTime->now ),
    );
}

sub GetOrder {
    my ( $self, %args ) = @_;
    return $self->call_api_method(
        method         => 'GetOrder',
        parameter_spec => {
            AmazonOrderId => {
                type     => 'IdList',
                required => 1,
            },
        },
        with_args       => {%args},
        filter_response => sub {
            my $root = shift;
            return $root;
        }
    );
}

sub GetServiceStatus {
    my ( $self, %args ) = @_;
    return $self->call_api_method(
        method          => 'GetServiceStatus',
        parameter_spec  => {},
        with_args       => {},
        filter_response => sub {
            my $root = shift;
            return $root;
        }
    );
}

sub ListOrderItems {
    my ( $self, %args ) = @_;
    return $self->call_api_method(
        method         => 'ListOrderItems',
        parameter_spec => {
            AmazonOrderId => {
                type     => 'string',
                required => 1,
            },
        },
        with_args       => {%args},
        filter_response => sub {
            my $root = shift;
            return $root;
        }
    );
}

sub ListOrderItemsByNextToken {
    my ( $self, %args ) = @_;
    return $self->call_api_method(
        method         => 'ListOrderItemsByNextToken',
        parameter_spec => {
            NextToken => {
                type     => 'string',
                required => 1,
            },
        },
        with_args       => {%args},
        filter_response => sub {
            my $root = shift;
            $self->convert( $root, HasNext => 'boolean' );
            return $root;
        }
    );
}

sub ListOrders {
    my ( $self, %args ) = @_;
    return $self->call_api_method(
        method         => 'ListOrders',
        parameter_spec => {
            CreatedAfter       => { type => 'datetime' },
            CreatedBefore      => { type => 'datetime' },
            LastUpdatedAfter   => { type => 'datetime' },
            LastUpdatedBefore  => { type => 'datetime' },
            OrderStatus        => { type => 'StatusList' },
            FulfillmentChannel => { type => 'FulfillmentList' },
            BuyerEmail         => { type => 'string' },
            SellerOrderId      => { type => 'string' },
            MaxResultsPerPage  => { type => 'nonNegativeInteger' },
        },
        with_args       => {%args},
        filter_response => sub {
            my $root = shift;
            return $root->{Orders}->{Order};
        }
    );
}

sub ListOrdersByNextToken {
    my ( $self, %args ) = @_;
    $self->call_api_method(
        method         => 'ListOrdersByNextToken',
        parameter_spec => {
            NextToken => {
                type     => 'string',
                required => 1,
            },
        },
        with_args       => {%args},
        filter_response => sub {
            my $root = shift;
            $self->convert( $root, HasNext => 'boolean' );
            return $root;
        }
    );
}

__PACKAGE__->meta->make_immutable;
1;
