use Test::More;
if( ! $ENV{WPP_TEST} || ! -f $ENV{WPP_TEST} ) {
    plan skip_all => 'No WPP_TEST env var set. Please see README to run tests';
}
else {
    plan tests => 1;
}

use Business::PayPal::API qw(DirectPayments);
#use_ok( 'Business::PayPal::API::DirectPayments' );
#########################

require 't/API.pl';

my %args = do_args();

my $pp = new Business::PayPal::API( %args );

my %resp = $pp->DoDirectPaymentRequest
                (
                 PaymentAction    => 'Sale',
		 OrderTotal    => 13.59,
                 TaxTotal       => 0.0,
                 ItemTotal  => 0.0,
                 CreditCardType      => 'Visa',
                 CreditCardNumber        => '4561435600988217',
                 ExpMonth	=> '01',
                 ExpYear	=> '2007',
                 CVV2       => '123',
                 FirstName      => 'JP',
                 LastName      => 'Morgan',
                 Street1  => '1st Street LaCausa',
                 Street2  => '',
                 CityName      => 'La',
                 StateOrProvince     => 'Ca',
                 PostalCode       => '90210',
                 Country   => 'US',
                 Payer    => 'mall@example.org',
                 CurrencyID  => 'USD',
                 IPAddress        => '10.0.0.1',
		 MerchantSessionID	=> '10113301',
                 );

is( $resp{Ack}, 'Success', "Successful request." );

if( $resp{Ack} ) {
    print STDERR <<"_PAYMENT_";

You may now login to your Business sandbox account and verify the
payment was received

_PAYMENT_
}
