#!/usr/bin/env perl

use warnings;
use strict "refs";
use Nagios::Monitoring::Plugin;
use HTTP::Request::Common;
use HTTP::Headers;
use HTTP::Cookies;
use LWP::UserAgent;
use JSON;
#use JSON::Parse;
use JSON::Parse 'read_json';
#use Nagios::Plugin;
use Data::Dumper;
use Encode;
use Switch;

use constant { true => 1, false => 0 };


my $np = Nagios::Monitoring::Plugin->new(
    usage => "Usage: %s -H|--Host host "
    . "[ -c|--critical <thresholds> ] [ -w|--warning <thresholds> ] "
    . "[ -E|--EMail ] "
    . "[ -P|--Password ] "
    . "[ -e|--entity site|solar|load|battery] " 
    . "[ -s|--sensor ] " 
    . "[ -t|--timeout <timeout> ] "
    . "[ --ignoressl ] "
    . "[ -h|--help ] ",
    version => '1.0',
    blurb   => 'Nagios plugin to check on Tesla Gateway/Powerwall 2',
    extra   => "\nExample: \n"
    . "check_tesla-gateway2.pl --url http://192.168.178.10 -E youruser -P yourpassword"
    . "              -e Site -s instant_power --warning :5 --critical :10 ",
    url     => 'http://www.creativeit.eu/software/nagios-plugins/check-tesla-gateway.html',
    plugin  => 'check_tesla-gateway2',
    timeout => 15,
    shortname => "CheckTeslaGateway2"
);

# add valid command line options and build them into your usage/help documentation.

$np->add_arg(
    spec => 'Host|H=s',
    help => '-H, --Host 192.168.178.10',
    required => 1,
);
$np->add_arg(
    spec => 'EMail|E=s',
    help => '-E, --EMail',
    required => 1,
);
$np->add_arg(
    spec => 'Password|P=s',
    help => '-P, --Password',
    required => 1,
);

$np->add_arg(
    spec => 'entity|e=s',
    help => '-e, --entity site|solar|load|battery',
    required => 1,
);
$np->add_arg(
    spec => 'sensor|s=s',
    help => '-s, --sensor ',
    required => 1,
);

$np->add_arg(
    spec => 'warning|w=s',
    help => '-w, --warning INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'critical|c=s',
    help => '-c, --critical INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'ignoressl',
    help => "--ignoressl\n   Ignore bad ssl certificates",
);


####  Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;

my $opt_host = $np->opts->Host;
my $opt_email = $np->opts->EMail;
my $opt_pass = $np->opts->Password;
my $opt_entity = $np->opts->entity;
my $opt_sensor = $np->opts->sensor;

if ($np->opts->verbose) { print "Verbose: Nagios Object \n"; print Dumper ($np);  print "#----\n" };


#### ----------- Set Contants and Variables -----------

my $baseurl = "https://" . $opt_host;

my $datafile_folder = "/var/cache/icinga/";
my $datafile_name = "check_tesla-gateway2_" . $opt_host . "_data";
my $datafile = $datafile_folder . $datafile_name;

my $json_response = "";
my $json_datafile = ();

my $epoc = time();
my $epoc_datafile = 0;

my $epoc_diff = 0;
my $epoc_age = 55;


#### ----------- Useragent -----------

my $ua = LWP::UserAgent->new;
my $cookies = HTTP::Cookies->new( );

$ua->env_proxy;
$ua->cookie_jar( $cookies );
$ua->agent('nagios_check_tesla-gateway2/1.0');
$ua->default_header('content-type' => 'application/json');
$ua->protocols_allowed( [ 'https' ] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

if ($np->opts->ignoressl) {
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
}

if ($np->opts->verbose) { print "\n#---- UA \n\nVerbose: Useragent \n"; print Dumper ($ua);  print "#----\n" };


#### ----------- Read old Session data -----------

## Read from Session Datafile
if ($np->opts->verbose) { print  "Verbose: ---- Read from Session Datafile ----\n" };

if ( -e $datafile ) {

	if ($np->opts->verbose) {print "Verbose: $datafile exists \n"};

	#open(SESSION_DATAFILE, $datafile);  
	open(SESSION_DATAFILE, '<:encoding(UTF-8)', $datafile);
	$json_datafile = decode_json( <SESSION_DATAFILE> ); 
	
	if ($np->opts->verbose) { print "Verbose: Have read " . length $json_datafile . " bytes from $datafile \n"};

	close (SESSION_DATAFILE);  
	
}
if ($np->opts->verbose) { print  "Verbose: ---- Got from file ----\n"; print Dumper ($json_datafile);  print "#----\n" };


## Calc epoc_diff using epoc and epoc from file
if ($np->opts->verbose) { print  "Verbose: ---- Calc epoc_diff using epoc and epoc from file ----\n" };

if ( length $json_datafile->{epoc} ) {
	$epoc_diff = $epoc - $json_datafile->{epoc};
	if ($np->opts->verbose) { print "#Verbose: epoc now: $epoc vs epoc file: " . $json_response->{epoc}. "\n" };
}
if ($np->opts->verbose) { print "#Verbose: epoc diff is: $epoc_diff \n" };


## Compare epoch with epoch from file and decide which path to go
if ($np->opts->verbose) { print  "Verbose: ---- Compare epoc with epoc from file ----\n" };


if ( length $json_datafile->{epoc} and $epoc_diff lt $epoc_age){
	
	if ($np->opts->verbose) { print "#Verbose: $epoc_diff is lower than $epoc_age; Using file content\n" };

	$json_response = $json_datafile;
	
} else {
	
	if ($np->opts->verbose) { print "#Verbose: $epoc_diff is higher than $epoc_age; Getting new data\n" };
	
	#### ----------- Auth -----------
	if ($np->opts->verbose) { print "\n#---- AUTH \n\n" };

	## Build URL
	my $urla = $baseurl .  "/api/login/Basic";
	# verbose
	if ($np->opts->verbose) { print "Verbose: Auth Url : " . $urla . "\n#----\n" };

	## Build payload
	#my $payload_tz = {
	#    timezone => 'Europe/Berlin',
	my $payload_array = {
		username => 'customer',
		password => $opt_pass,
		email => $opt_email};
	my $payload = encode_json( $payload_array );
	# verbose
	if ($np->opts->verbose) { print "Verbose: Auth payload : " . $payload . "\n#----\n" };

	## Get A Response
	my $aresponse = $ua->request(POST $urla, 'content-type' => 'application/json', Content => $payload);
	if (not $aresponse->is_success) {
		$np->nagios_exit(CRITICAL, "Authentication to " . $urla . " failed: ".$aresponse->status_line);
	}
	# verbose
	#if ($np->opts->verbose) { print "Verbose: Data Response \n"; print Dumper ($aresponse);  print "#----\n" };


	## Parse Auth

	# decode JSON
	my $json_aresponse = decode_json($aresponse->content);
	if ($np->opts->verbose) { print "Verbose: Auth JSON Response \n"; print Dumper ($json_aresponse);  print "#----\n"};

	# get token
	my $atoken = $json_aresponse->{'token'};
	if ($np->opts->verbose) { print "Verbose: Auth token :" . $atoken . "\n#----\n" };

	# set new header

	my $headers = HTTP::Headers->new(
		  Content_Type => 'application/json',
		  Authorization => 'Bearer ' . $atoken);
	$ua->default_headers( $headers );


	#### ----------- Data -----------

	## Build URL

	my $urld = $baseurl .  "/api/meters/aggregates";
	# verbose
	if ($np->opts->verbose) { print "Verbose: Data Url : " . $urld . "\n#----\n" };

	## Get D Response
	my $response = $ua->request(GET $urld, 'Content-type' => 'application/json');
	if (not $response->is_success) {
		$np->nagios_exit(CRITICAL, "Connection to " . $urld . " failed: ".$response->status_line);
	}
	# verbose
	#if ($np->opts->verbose) { print "Verbose: Data Response \n"; print Dumper ($response);  print "#----\n" };


    #### ----------- Parse JSON -----------
	
	$json_response = decode_json($response->content);
	if ($np->opts->verbose) { print "Verbose: JSON Response \n"; print Dumper ($json_response);  print "#----\n"};


	#### ----------- Store Data File -----------

	## Add epoch as timestamp or request
	$json_response->{epoc} = $epoc;

	## write JSON to file
    unless(open SESSION_DATAFILE, '>:encoding(UTF-8)', $datafile) {
        print "Unable to create session data file \"$datafile\"\n";
        exit 3;
    }
    print SESSION_DATAFILE encode_json($json_response); 
    close (SESSION_DATAFILE);
	if ($np->opts->verbose) { print "Verbose: Wrote to $datafile \n"};
} 



#### ----------- Parse -----------

## Compute value and limits
my @warning = split(',', $np->opts->warning);
my @critical = split(',', $np->opts->critical);


## Get value
my $check_value;
my $check_title;
my $check_probe;
my $check_scale;

my $check_scale_in_list = 1;

# Check if entity exists 
if( length $json_response->{lc($opt_entity)} ) {

	## VALUE
	$check_value = $json_response->{lc($opt_entity)}->{lc($opt_sensor)};
	if ($np->opts->verbose) { print "Verbose: JSON Parse - check_value \n" . $check_value . "\n#----\n" };
	
    # Check on value
	# if( isset( $check_value ){


	## TITLE an PROBE
    $check_title = lc($opt_entity) . "__" . lc($opt_sensor);
    if ($np->opts->verbose) { print "Verbose: JSON Parse - check_title \n" . $check_title . "\n#----\n" };

	$check_probe = $check_title;		
    if ($np->opts->verbose) { print "Verbose: JSON Parse - check_probe \n" . $check_probe . "\n#----\n" };


	## SCALE
	if (index($check_title, 'power') != -1) {
		$check_scale = 'W';
	} 
	elsif (index($check_title, 'frequency') != -1) {
		$check_scale = 'Hz';
	}
	elsif (index($check_title, 'energy') != -1) {
		$check_scale = 'Wh';
	}
	elsif (index($check_title, 'voltage') != -1) {
		$check_scale = 'V';
	}
	elsif (index($check_title, 'current') != -1) {
		$check_scale = 'A';
	}
	elsif (index($check_title, 'num') != -1) {
		$check_scale = '#';
	}
	else
	{ 
		$check_scale = 'noScale';
	}

    if ($np->opts->verbose) { print "Verbose: JSON Parse - check_scale \n" . $check_scale . "\n#----\n" };

}
### not implemented
else { 
    $check_value = -1;
    $check_title = "Sensor " . $opt_sensor . " on Entity " . $opt_entity . " is not supported";
    $check_probe = "Sensor " . $opt_sensor . " on Entity " . $opt_entity . " is not supported";
    $check_scale = "";
	$check_scale_in_list = 0
}


## Check value against thresholds...
my $result = -1;
$result = $np->check_threshold(
    check => $check_value,
    warning => $np->opts->warning,
    critical => $np->opts->critical
);

if ($np->opts->verbose) { 
    print "Verbose: Value $check_value "; 
    print "\n         Scale  $check_scale"; 
    print "\n         Title  $check_title"; 
    print "\n         Probe  $check_probe"; 
    print "\n         Result $result"; 
    print "\n#----\n"
};


#### Compute value and limits

my @statusmsg;

if ($check_scale_in_list eq 1) {
    push(@statusmsg, "$check_probe: ".$check_value.$check_scale);
    $np->add_perfdata(
        label => $check_title,
        value => $check_value,
        uom => $check_scale, 
        threshold => $np->set_thresholds( warning => $np->opts->warning, critical => $np->opts->critical),
    ); 
} else {
    push(@statusmsg, "$check_probe: ".$check_value);
    $np->add_perfdata(
        label => $check_title . "(" . $check_scale . ")",
        value => $check_value,
        threshold => $np->set_thresholds( warning => $np->opts->warning, critical => $np->opts->critical),
    ); 
};

if ($np->opts->verbose) { print "Verbose: StatusMsg"; print Dumper (@statusmsg);  print "#----\n"};


#### Finally

$np->nagios_exit(
    return_code => $result,
    message     => join(', ', @statusmsg),
);
