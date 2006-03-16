package Business::PayPal::API;

use 5.008001;
use strict;
use warnings;

use SOAP::Lite 0.67;
use Carp qw(carp);

our $VERSION = '0.01';
our $CVS_VERSION = '$Id: API.pm,v 1.2 2006/03/16 23:33:49 scott Exp $';
our $Debug = 0;

## NOTE: This package exists only until I can figure out how to use
## NOTE: SOAP::Lite's WSDL support for complex types and importing
## NOTE: type definitions, at which point this module will become much
## NOTE: smaller (or non-existent).

sub C_api_sandbox () { 'https://api.sandbox.paypal.com/2.0/' }
sub C_api_live    () { 'https://api.paypal.com/2.0/' }
sub C_xmlns_pp    () { 'urn:ebay:api:PayPalAPI' }
sub C_xmlns_ebay  () { 'urn:ebay:apis:eBLBaseComponents' }
sub C_version     () { '1.0' }

## this is an inside-out object. Make sure you 'delete' additional
## members in DESTROY() as you add them.
my %Soap;
my %Header;

my %H_PKCS12File;     ## path to certificate file (pkc12)
my %H_PKCS12Password; ## password for certificate file (pkc12)
my %H_CertFile;       ## PEM certificate
my %H_KeyFile;        ## PEM private key

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless \(my $fake), $class;

    ## if you add new args, be sure to update the test file's @variables array
    $args{Username}  ||= '';
    $args{Password}  ||= '';
    $args{Signature} ||= '';
    $args{Subject}   ||= '';
    $args{sandbox} = 1 unless exists $args{sandbox};

    $H_PKCS12File{$self}     = $args{PKCS12File}     || '';
    $H_PKCS12Password{$self} = $args{PKCS12Password} || '';
    $H_CertFile{$self}       = $args{CertFile}       || '';
    $H_KeyFile{$self}        = $args{KeyFile}        || '';

    if( $args{sandbox} ) {
	$Soap{$self} = SOAP::Lite
	    ->proxy( C_api_sandbox )
	    ->uri( C_xmlns_pp );
    }

    else {
	$Soap{$self} = SOAP::Lite
	    ->proxy( C_api_live )
	    ->uri( C_xmlns_pp );
    }

    $Header{$self} = SOAP::Header
      ->name( RequesterCredentials => \SOAP::Header->value
	      ( SOAP::Data->name( Credentials => \SOAP::Data->value
				  ( SOAP::Data->name( Username  => $args{Username} )->type(''),
				    SOAP::Data->name( Password  => $args{Password} )->type(''),
				    SOAP::Data->name( Signature => $args{Signature} )->type(''),
				    SOAP::Data->name( Subject   => $args{Subject} )->type(''),
				  ),
				)->attr( {xmlns => C_xmlns_ebay} )
	      )
	    )->attr( {xmlns => C_xmlns_pp} )->mustUnderstand(1);

    return $self;
}

sub DESTROY {
    my $self = $_[0];

    delete $Soap{$self};
    delete $Header{$self};

    delete $H_PKCS12File{$self};
    delete $H_PKCS12Password{$self};
    delete $H_CertFile{$self};
    delete $H_KeyFile{$self};

    my $super = $self->can("SUPER::DESTROY");
    goto &$super if $super;
}

sub version_req {
    return SOAP::Data->name( Version => C_version )
      ->type('xs:string')->attr( {xmlns => C_xmlns_ebay} );
}

sub doCall {
    my $self = shift;
    my $method_name = shift;
    my $request = shift;
    my $method = SOAP::Data->name( $method_name )->attr( {xmlns => C_xmlns_pp} );

    my $som;
    {
	no warnings 'redefine';
	local *SOAP::Deserializer::typecast = sub {shift; return shift};
	$ENV{HTTPS_PKCS12_FILE}     || (local $ENV{HTTPS_PKCS12_FILE}     = $H_PKCS12File{$self});
	$ENV{HTTPS_PKCS12_PASSWORD} || (local $ENV{HTTPS_PKCS12_PASSWORD} = $H_PKCS12Password{$self});
	$ENV{HTTPS_CERT_FILE}       || (local $ENV{HTTPS_CERT_FILE}       = $H_CertFile{$self});
	$ENV{HTTPS_KEY_FILE}        || (local $ENV{HTTPS_KEY_FILE}        = $H_KeyFile{$self});

	if( $Debug ) {
	    print STDERR SOAP::Serializer->envelope(method => $method, 
                                                    $Header{$self}, $request), "\n";
	}

	$Soap{$self}->readable( $Debug );
	$Soap{$self}->outputxml( $Debug );
	$som = $Soap{$self}->call( $Header{$self}, $method => $request );
    }

    if( $Debug ) {
	print STDERR $som, "\n";
	$som = SOAP::Deserializer->deserialize($som);  ## FIXME: this
                                                       ## doesn't put
                                                       ## things back
                                                       ## quite right
    }

    if( ref($som) && $som->fault ) {
        carp "Fault: " . $som->faultdetail . "\n";
        return;
    }

    return $som;
}

sub getFields {
    my $self = shift;

    my $som  = shift;
    my $path = shift;
    my $response = shift;
    my $fields = shift;

    for my $field ( keys %$fields ) {
        if( my $value = $som->valueof("$path/$fields->{$field}") ) {
            $response->{$field} = $value;
        }
    }
}

sub getErrors {
    my $self = shift;
    my $som  = shift;
    my $path = shift;
    my $details = shift;

    $details->{Ack} = $som->valueof("$path/Ack") || '';

    unless( $details->{Ack} =~ /^[Ss]uccess$/ ) {
        my @errors = ();

        for my $enode ( $som->valueof("$path/Errors") ) {
            push @errors, { LongMessage => $enode->{LongMessage},
                            ErrorCode   => $enode->{ErrorCode}, };
        }
        $details->{Errors} = \@errors;

        return 1;
    }

    return;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Business::PayPal::API - PayPal API

=head1 SYNOPSIS

  use Business::PayPal::API;

  ## certificate authentication
  my $pp = new Business::PayPal::API
            ( Username       => 'my_api1.domain.tld',
              Password       => 'this_is_my_password',
              PKCS12File     => '/path/to/cert.pck12',
              PKCS12Password => '/path/to/certpw.pck12',
              sandbox        => 1 );

  ## PEM cert authentication
  my $pp = new Business::PayPal::API
            ( Username    => 'my_api1.domain.tld',
              Password    => 'this_is_my_password',
              CertFile    => '/path/to/cert.pem',
              KeyFile     => '/path/to/cert.pem',
              sandbox     => 1 );

  ## 3-token authentication
  my $pp = new Business::PayPal::API
            ( Username   => 'my_api1.domain.tld',
              Password   => 'Xdkis9k3jDFk39fj29sD9',  ## supplied by PayPal
              Signature  => 'f7d03YCpEjIF3s9Dk23F2V1C1vbYYR3ALqc7jm0UrCcYm-3ksdiDwjfSeii',  ## ditto
              sandbox    => 1 );


=head1 DESCRIPTION

B<Business::PayPal::API> supports both certificate authentication and
the new 3-token authentication.

It also support PayPal's development I<sandbox> for testing. See the
B<sandbox> parameter to B<new()> below for details.

=head2 new

Creates a new B<Business::PayPal::API> object. This is usually invoked
from a subclass.

A note about certificate authentication: You may use either PKCS#12
certificate authentication or PEM certificate authentication. See
options below.

=over 4

=item B<Username>

Required. This is the PayPal API username, usually in the form of
'my_api1.mydomain.tld'. You can find or create your credentials by
logging into PayPal (if you want to do testing, as you should, you
should also create a developer sandbox account) and going to:

  My Account -> Profile -> API Access -> Request API Credentials

=item B<Password>

Required. If you use certificate authentication, this is the PayPal
API password you created yourself when you setup your certificate. If
you use 3-token authentication, this is the password PayPal assigned
you, along with the "API User Name" and "Signature Hash".

=item B<Subject>

Optional. This is used by PayPal to authenticate 3rd party billers
using your account. See the documents in L<SEE ALSO>.

=item B<Signature>

Required for 3-token authentication. This is the "Signature Hash" you
received when you did "Request API Credentials" in your PayPal
Business Account.

=item B<PKCS12File>

Required for PKCS#12 certificate authentication, unless the
B<HTTPS_PKCS12_FILE> environment variable is already set.

This contains the path to your private key for PayPal
authentication. It is used to set the B<HTTPS_PKCS12_FILE> environment
variable. You may set this environment variable yourself and leave
this field blank.

=item B<PKCS12Password>

Required for PKCS#12 certificate authentication, unless the
B<HTTPS_PKCS12_PASSWORD> environment variable is already set.

This contains the PKCS#12 password for the key specified in
B<PKCS12File>. It is used to set the B<HTTPS_PKCS12_PASSWORD>
environment variable. You may set this environment variable yourself
and leave this field blank.

=item B<CertFile>

Required for PEM certificate authentication, unless the
HTTPS_CERT_FILE environment variable is already set.

This contains the path to your PEM format certificate given to you
from PayPal (and accessible in the same location that your Username
and Password and/or Signature Hash are found) and is used to set the
B<HTTPS_CERT_FILE> environment variable. You may set this environment
variable yourself and leave this field blank.

You may combine both certificate and private key into one file and set
B<CertFile> and B<KeyFile> to the same path.

=item B<KeyFile>

Required for PEM certificate authentication, unless the HTTPS_KEY_FILE
environment variable is already set.

This contains the path to your PEM format private key given to you
from PayPal (and accessible in the same location that your Username
and Password and/or Signature Hash are found) and is used to set the
B<HTTPS_KEY_FILE> environment variable. You may set this environment
variable yourself and leave this field blank.

You may combine both certificate and private key into one file and set
B<CertFile> and B<KeyFile> to the same path.

=item B<sandbox>

Required. If set to true (default), B<Business::PayPal::API> will
connect to PayPal's development sandbox, instead of PayPal's live
site. *You must explicitly set this to false (0) to access PayPal's
live site*.

If you use PayPal's development sandbox for testing, you must have
already signed up as a PayPal developer and created a Business sandbox
account and a Buyer sandbox account (and make sure both of them have
B<Verified> status in the sandbox).

When testing with the sandbox, you will use different usernames,
passwords, and certificates (if using certificate authentication) than
you will when accessing PayPal's live site. Please see the PayPal
documentation for details. See L<SEE ALSO> for references.

PayPal's sandbox reference:

L<https://www.paypal.com/IntegrationCenter/ic_sandbox.html>

=back

=head1 ERROR HANDLING

Every API call should return an B<Ack> response, whether I<Success>,
I<Failure>, or otherwise (depending on the API call). If it returns
any non-success value, you can find an I<Errors> entry in your return
hash, whose value is a listref of hashrefs:

 [ { ErrorCode => 10002,
     LongMessage => "Invalid security header" },

   { ErrorCode => 10030,
     LongMessage => "Some other error" }, ]

You can retrieve these errors like this:

  %response = $pp->doSomeAPICall();
  if( $response{Ack} ne 'Success' ) {
      for my $err ( @{$response{Errors}} ) {
          warn "Error: " . $err->{LongMessage} . "\n";
      }
  }

=head1 TESTING

Testing the B<Business::PayPal::API::*> modules requires that you
create a file containing your PayPal Developer Sandbox authentication
credentials (e.g., API certificate authentication or 3-Token
authentication signature, etc.) and setting the B<WPP_TEST>
environment variable to point to this file.

The format for this file is as follows:

  Username = your_api.username.com
  Password = your_api_password

and then ONE of the following options:

  a) supply 3-token authentication signature

      Signature = xxxxxxxxxxxxxxxxxxxxxxxx

  b) supply PEM certificate credentials

      CertFile = /path/to/cert_key_pem.txt
      KeyFile  = /path/to/cert_key_pem.txt

  c) supply PKCS#12 certificate credentials

      PKCS12File = /path/to/cert.p12
      PKCS12Password = pkcs12_password

You may also set the appropriate HTTPS_* environment variables for b)
and c) above (e.g., HTTPS_CERT_FILE, HTTPS_KEY_FILE,
HTTPS_PKCS12_File, HTTPS_PKCS12_PASSWORD) in lieu of putting this
information in a file.

Then use "WPP_TEST=my_auth.txt make test" (for Bourne shell derivates) or
"setenv WPP_TEST my_auth.txt && make test" (for C-shell derivates).

See 'auth.sample.*' files in this package for an example of the file
format. Variables are case-*sensitive*.

Any of the following variables are recognized:

  Username Password Signature Subject
  CertFile KeyFile PKCS12File PKCS12Password
  BuyerEmail

Note: PayPal authentication may I<fail> if you set the certificate
environment variables and attempt to connect using 3-token
authentication (i.e., PayPal will use the first authentication
credentials presented to it, and if they fail, the connection is
aborted).

If you are experiencing PayPal authentication errors, you should make
sure:

   * your username and password match those found in your PayPal
     Business account sandbox (this is not the same as your regular
     account.

   * you're not trying to use your live username and password for
     sandbox testing and vice versa.

   * if you use certificate authentication, your certificate must be
     the correct one (live or sandbox) depending on what you're doing.

   * if you use 3-Token authentication (i.e., Signature), you don't
     have any B<PKCS12*> parameters or B<CertFile> or B<KeyFile>
     parameters in your constructor AND that none of the corresponding
     B<HTTPS_*> environment variables are set.

See the DEBUGGING section below for further hints.

=head1 DEBUGGING

You can see the raw SOAP XML sent and received by
B<Business::PayPal::API> by setting it's B<$Debug> variable:

  $Business::PayPal::API::Debug = 1;
  $pp->SetExpressCheckout( %args );

these will print on STDERR (so check your error_log if running inside
a web server).

Unfortunately, while doing this, it also doesn't put things back the
way they should be, so this should not be used in a production
environment to troubleshoot (until I get this fixed). Patches gladly
accepted which would let me get the correct SOM object back after
serialization.

Summary: while the output of $Debug is extremely useful in tracking
down API problems, don't use B<$Debug> except in a sandbox until I can
get the deserialziation of the SOM object fixed.

=head1 DEVELOPMENT

If you are a developer wanting to extend B<API> for other PayPal API
calls, you can review F<RefundTransaction.pm> or B<ExpressCheckout.pm>
for examples on how to do this.

=head2 EXPORT

None by default.

=head1 CAVEATS

Because I haven't figured out how to make SOAP::Lite read the WSDL
definitions directly and simply implement those (help, anyone?), I
have essentially recreated all of those WSDL structures internally in
this module.

If PayPal changes their API (adds, removes, or changes parameters),
this module *may stop working*. I do not know if PayPal will preserve
backward compatibility. That said, you can help me keep this module
up-to-date if you notice such an event occuring.

While this module was written, PayPal added 3-token authentication,
which while being trivial to support and get working, is a good
example of how quickly non-WSDL SOAP can get behind.

Also, I didn't implement a big fat class hierarchy to make this module
"academically" correct. You'll notice that I fudged two colliding
parameter names in B<DoExpressCheckoutPayment> as a result. The good
news is that this was written quickly, works, and is dead-simple to
use. The bad news is that this sort of collision might occur again as
more and more data is sent in the API (call it 'eBay API bloat'). I'm
willing to take the risk this will be rare (PayPal--please make it
rare!).

=head1 SEE ALSO

L<SOAP::Lite>, L<https://www.paypal.com/IntegrationCenter/ic_pro_home.html>,
L<https://www.paypal.com/IntegrationCenter/ic_expresscheckout.html>,
L<https://www.sandbox.paypal.com/en_US/pdf/PP_Sandbox_UserGuide.pdf>,
L<https://developer.paypal.com/en_US/pdf/PP_APIReference.pdf>

=head1 AUTHOR

Scott Wiersdorf, E<lt>scott@perlcode.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Scott Wiersdorf

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
