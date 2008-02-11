
#!/usr/bin/perl

use HTTP::Proxy;
use HTTP::Recorder;

my $proxy = HTTP::Proxy->new();

# create a new HTTP::Recorder object
my $agent = HTTP::Recorder->new(file => "/log/http.log");

# set the log file (optional)
#$agent->file("/log/proxy.log");

# set HTTP::Recorder as the agent for the proxy
$proxy->host("");
$proxy->port( 8080 );
$proxy->maxchild( 0 );
$proxy->agent( $agent );

# start the proxy
$proxy->start();

1;
    