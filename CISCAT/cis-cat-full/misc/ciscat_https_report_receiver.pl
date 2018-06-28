#!/usr/bin/perl

use CGI;
use Fcntl qw(:mode :flock SEEK_END);
use strict;

#
# This is a CGI script that expects to be invoked by a web server, such as
# Apache HTTP Server. This script has three configuration options that
# require attention:
#
#       - reports_directory
#       - log_path
#       - max_upload_size_mb
#
#       Information about these options is below.
#
# Once this script is deployed, visit it in a web browser to confirm it is
# configured properly. For example:
#
#       http://internal.web.server/ciscat_report_sink.pl?setup=1
#
# If the script outputs 'Report saving appears to be functional.' then it's
# ready for use.
#
# Note: Errors related to logging are not critical. Therefore, informational
# messages regarding the misconfiguration of logging may also be presnt. It is
# recommended that logging-related errors be resolved.
#
# Once this script is functional, CISCAT can send XML reports to it. For example:
#
#       ./CISCAT.sh -b benchmarks/CIS_Red_Hat_Enterprise_Linux_6_Benchmark_v2.0.0 -u https://intranet/ciscat_report_sink.pl 
#
# See the CISCAT Users Guide for a complete list of CISCAT's command line options.
#

#
# CONFIGURATION OPTION: Location to store received reports.
#
#       - This directory must be +r and +w by the user or group this script executes as.
#       - Do not set $reports_directory to a directory that is accessible via the web server.
#

my $reports_directory = '/opt/ciscat/reports';

#
# CONFIGURATION OPTION: Location of upload activity log.
#
#       - This directory must be +r and +w by the user or group this script executes as.
#       - Do not log_path to a location that is accessible via the web server.
#

my $log_path = '/var/log/ciscat_report_sink.log';

#
# CONFIGURATION OPTION: Maximum size of upload.
#
#       - If this value is set too low, all reports will be blank.
#       - If this value is set too high, opportunity to consume resources increases.

my $max_upload_size_mb = 10;

#
# NO FURTHER CONFIGURATION REQUIRED
#

#
# Get values to build file name and log entries from.
#

my $remote_ip = $ENV{'REMOTE_ADDR'};
my $timestamp = time;

my $report_name = $remote_ip . "-" . "report" . "-" . $timestamp . ".xml";
my $report_path = $reports_directory . "/" . $report_name;

sub log_request
{
        my $level       = shift;
        my $message     = shift;

        print "$level: $message<br/>";

        # Open log file for appending.
        if (! open(LOG, ">>$log_path") )
        {
                print "INFO: Can't open log file for writing - $!. Ensure log path exists and is writable by this script.<br/>";
                return;
        }

        # Obtain exclusive lock on log file.
        if (! flock(LOG, LOCK_EX) )
        {
                print "INFO: Can't lock log file - $!<br/>";
                return;
        }

        # Seek to the end of the file in case the log has be written to since we opened it.
        if (! seek(LOG,0, SEEK_END) )
        {
                print "INFO: Can't seek log file - $!<br/>";
                return;
        }

        # Ensure message does not contain double quotes. Double quotes would impact ability to parse the log file.
        $message =~ s/"/'/g;

        print LOG scalar localtime() . ",$level,$remote_ip,\"$message\"\n";

        # Unlock log file and close handle
        flock(LOG, LOCK_UN);
        close (LOG);

        return;
}

#
# Set maximum upload size.
#

$CGI::POST_MAX = 1024 * 1024 * $max_upload_size_mb;

print "Content-type: text/html\n\n";

my $cgi = new CGI();
my $report = $cgi->param('ciscat-report');
my $setup = $cgi->param('setup');

if ( defined($setup) )
{

        # provide fake report contents to test with.
        $report = '<?xml version="1.0" encoding="UTF-8"?>Test';

        my $mode = undef;

        #
        # Confirm permission on report directory prevent o+r and o+w
        #


        if ( -d $reports_directory )
        {


                $mode = (stat($reports_directory))[2];

                if ( ($mode & S_IWOTH) > 0 )
                {
                        log_request("INFO", "Report directory is world writable. It shouldn't be.");
                }

                $mode = (stat($reports_directory))[2];

                if ( ($mode & S_IROTH) > 0 )
                {
                        log_request("INFO", "Report directory is world readable. It shouldn't be.");
                }

        }

        #
        # Confirm permission on log file prevent o+r and o+w
        #

        if ( -e $log_path )
        {
                $mode = (stat($log_path))[2];

                if ( ($mode & S_IWOTH) > 0 )
                {
                        log_request("INFO", "Log file is world writable. It shouldn't be.");
                }

                $mode = (stat($log_path))[2];

                if ( ($mode & S_IROTH) > 0 )
                {
                        log_request("INFO", "Log file is world readable. It shouldn't be.");
                }
        }

}

if ( ! defined($report) )
{
        log_request("ERROR", "No report provided or report is too large.");
        exit(-1);
}

#
# Ensure the uploaded file is an XML document that starts  with the following:
#
#       <?xml version="1.0" encoding="UTF-8"?>
#

if ( $report !~ m/^\<\?xml\s+version="1.0"\s+encoding="UTF-8"\?\>/ )
{
        my $sample = substr($report, 0, 50);
        log_request("ERROR", "Invalid report provided. ($sample)");
        exit(-1);
}

#
# Open file to write report into.
#

if (! open(OUTFILE, ">$report_path") )
{
        log_request("ERROR", "Can't open report for writing - $!. Ensure report directory exists and is writable by this script.");
        exit(-1);
}

#
# Write report to file.
#

print OUTFILE $report;

#
# Set permissions on report
#

chmod(0400, $report_path);

#
# Close file
#

close(OUTFILE);



if ( defined($setup) )
{
        log_request("INFO", "Report saving appears to be functional.");
}
else
{
        log_request("INFO", "File ($report_name) uploaded.");
}

