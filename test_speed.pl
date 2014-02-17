#!/usr/bin/perl
use strict; # can be viewed in http://smilehealth.co.il/cgi-bin/prog/test_speed.pl
use Time::HiRes;   # only used for profiling (checking performance)

# results in Nov  4 2008:   Elapsed: 0.012
#   but in practise, takes 0.7 to 1 second :
# il-aleph06.corp.exlibrisgroup.com-20(1) VIR01-ORIM>>foreach f ( 1 2 3 4 5 6 7 8 9 0 )
 # date
 # wget "http://smilehealth.co.il/cgi-bin/prog/test_speed.pl" ; rm test_speed.pl
 # date
# end

my $start = [ Time::HiRes::gettimeofday() ];  my $elapsed=0;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
my $q=new CGI;

print $q->header(-charset=>'utf-8');
$elapsed = Time::HiRes::tv_interval( $start ); #debug ("Elapsed: $elapsed seconds");

print "Elapsed: $elapsed\n";
exit 0;
