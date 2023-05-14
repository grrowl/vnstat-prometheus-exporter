#!/usr/bin/perl -w

# vnstat-metrics.cgi -- Prometheus compatible metrics endpoint output from vnStat data
# copyright (c) 2022 Teemu Toivola <tst at iki dot fi>
# released under the GNU General Public License

use strict;
use JSON::PP;
use HTTP::Daemon;
use HTTP::Status;

# location of vnstat binary
my $vnstat_cmd = '/usr/bin/vnstat';

my @data_resolutions = ('fiveminute', 'hour', 'day', 'month', 'year');

# Create an HTTP::Daemon instance listening on port 9955
my $d = HTTP::Daemon->new(
    LocalAddr => $ENV{'VNSTAT_METRICS_HOST'} // 'localhost',
    LocalPort => 9955,
) || die "Cannot create HTTP::Daemon instance: $!";

print "HTTP server listening on ", $d->url, "\n";

# Enter an event loop to handle incoming requests
while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if ($r->method eq 'GET') {
            my $response_text = generate_response();
            $c->send_response(HTTP::Response->new(RC_OK, undef, undef, $response_text));
        } else {
            $c->send_error(RC_FORBIDDEN);
        }
    }
    $c->close;
    undef($c);
}

sub generate_response {
    my $response = "Content-Type: text/plain\n\n";

    my $json_data = `$vnstat_cmd --json s 1`;

    my $data = "";
    eval { $data = decode_json($json_data) };
    if ($@) {
        $response .= "# Error: Invalid command output: $json_data\n";
        return $response;
    }

    if (not defined $data->{'vnstatversion'}) {
        $response .= "# Error: Expected content from command output missing\n";
        return $response;
    }

    if (not defined $data->{'interfaces'}[0]) {
        $response .= "# Error: No interfaces found in command output\n";
        return $response;
    }

    if (not defined $data->{'interfaces'}[0]{'created'}{'timestamp'}) {
        $response .= "# Error: Incompatible vnStat version used\n";
        return $response;
    }

    $response .= "# vnStat version: ".$data->{'vnstatversion'}."\n";

    $response .= print_totals($data);

    my @data_resolutions = ('fiveminute', 'hour', 'day', 'month', 'year');
    foreach my $data_resolution ( @data_resolutions ) {
        $response .= print_data_resolution($data_resolution, $data);
    }

    return $response;
}

sub print_totals {
    my ($data) = @_;

    my $output = "";

    $output .= "\n# HELP vnstat_interface_total_received_bytes All time total received (rx) bytes\n";
    $output .= "# TYPE vnstat_interface_total_received_bytes counter\n";

    foreach my $interface ( @{ $data->{'interfaces'} } ) {
        my $interface_alias = get_interface_alias($interface);
        $output .= "vnstat_interface_total_received_bytes{interface=\"$interface->{'name'}\",alias=\"$interface_alias\"} $interface->{'traffic'}{'total'}{'rx'} $interface->{'updated'}{'timestamp'}000\n";
    }
$output .= "\n# HELP vnstat_interface_total_transmitted_bytes All time total transmitted (tx) bytes\n";
$output .= "# TYPE vnstat_interface_total_transmitted_bytes counter\n";

foreach my $interface ( @{ $data->{'interfaces'} } ) {
    my $interface_alias = get_interface_alias($interface);
    $output .= "vnstat_interface_total_transmitted_bytes{interface=\"$interface->{'name'}\",alias=\"$interface_alias\"} $interface->{'traffic'}{'total'}{'tx'} $interface->{'updated'}{'timestamp'}000\n";
}

return $output;
}

sub print_data_resolution {
    my ($resolution, $data) = @_;
    my $output_count = 0;
    my $output = "";

    $output .= "\n# HELP vnstat_interface_".$resolution."_received_bytes Received (rx) bytes for current $resolution\n";
    $output .= "# TYPE vnstat_interface_".$resolution."_received_bytes gauge\n";

    $output_count = 0;
    foreach my $interface ( @{ $data->{'interfaces'} } ) {
        my $interface_alias = get_interface_alias($interface);
        if (defined $interface->{'traffic'}{$resolution}) {
            $output .= "vnstat_interface_".$resolution."_received_bytes{interface=\"$interface->{'name'}\",alias=\"$interface_alias\"} $interface->{'traffic'}{$resolution}[0]{'rx'} $interface->{'updated'}{'timestamp'}000\n";
            $output_count++;
        }
    }
    if ($output_count == 0) {
        $output .= "# no data\n";
    }

    $output .= "\n# HELP vnstat_interface_".$resolution."_transmitted_bytes Transmitted (tx) bytes for current $resolution\n";
    $output .= "# TYPE vnstat_interface_".$resolution."_transmitted_bytes gauge\n";

    $output_count = 0;
    foreach my $interface ( @{ $data->{'interfaces'} } ) {
        my $interface_alias = get_interface_alias($interface);
        if (defined $interface->{'traffic'}{$resolution}) {
            $output .= "vnstat_interface_".$resolution."_transmitted_bytes{interface=\"$interface->{'name'}\",alias=\"$interface_alias\"} $interface->{'traffic'}{$resolution}[0]{'tx'} $interface->{'updated'}{'timestamp'}000\n";
            $output_count++;
        }
    }
    if ($output_count == 0) {
        $output .= "# no data\n";
    }

    return $output;
}


################


sub get_interface_alias
{
	my ($interface) = @_;
	my $interface_alias = $interface->{'alias'};
	if (length($interface_alias) == 0) {
		$interface_alias = $interface->{'name'};
	}
	return $interface_alias;
}

print "Content-Type: text/plain\n\n";

my $json_data = `$vnstat_cmd --json s 1`;

my $data = "";
eval { $data = decode_json($json_data) };
if ($@) {
	print "# Error: Invalid command output: $json_data\n";
	exit 1;
}

if (not defined $data->{'vnstatversion'}) {
	print "# Error: Expected content from command output missing\n";
	exit 1;
}

if (not defined $data->{'interfaces'}[0]) {
	print "# Error: No interfaces found in command output\n";
	exit 1;
}

if (not defined $data->{'interfaces'}[0]{'created'}{'timestamp'}) {
	print "# Error: Incompatible vnStat version used\n";
	exit 1;
}

print "# vnStat version: ".$data->{'vnstatversion'}."\n";

print_totals($data);

foreach my $data_resolution ( @data_resolutions ) {
	print_data_resolution($data_resolution, $data);
}
