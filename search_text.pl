#!/usr/bin/perl
use strict; 
# can be viewed in http://smilehealth.co.il/cgi-bin/prog/search_text.pl?q=%D7%9E
use Time::HiRes;
# use utf8; # not needed
use Encode qw(encode);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
my $q=new CGI;
my $start = [ Time::HiRes::gettimeofday() ];  my $elapsed=0;
print $q->header(-charset=>'utf-8');

(my $html = <<'HERE') =~ s/^\s+//gm;
<HTML>
<HEAD>
        <TITLE>sss</TITLE>
        <META HTTP-EQUIV="Content-Type" CONTENT="text/html; CHARSET=utf-8">
</HEAD>
<BODY dir=RTL>
<FORM method="GET" name="myform">
	<input name="q" value="חֹשֶׁךְ">
	<input type="submit" value="חפש">
</FORM>
HERE

my $query='';
if (defined $q->param('q')) {
	$query =  trim($q->param('q'));
	$query = remove_nikud($query);
	$html=~s/value=".*?"/value="$query"/;
} else {
	print "הקלד מילה לחיפוש<br>\n";
}
print "$html\n";

print "query: $query<br>\n";

	my $in_file = 'bereshit_hash.txt';
        open( my $fh, $in_file ) or die "cannot open file $in_file $!\n";
        my $text = do { local( $/ ) ; <$fh> } ;
        close ($fh);
	$text = remove_nikud($text);

	#my @all_words = split /\n/,$text;
	foreach my $word (split /\n/,$text) {
		# print "ooo: $word<br>\n";
		if ($word=~/$query/) {
			# print "<br>ooo: $word<br>\n";
			(my $pointer, my $the_word) = split /=/,$word;
			(my $sefer, my $perek, my $pasuk, my $mila) = split /,/,$pointer;
			my $link_to_wikitext = 'http://he.wikisource.org/w/index.php?title='."$sefer $perek $pasuk";
			print "$the_word (<a href=\"$link_to_wikitext\">$sefer $perek, $pasuk</a>)<br>\n";

		}

	}
	# print "$text\n";








$elapsed = Time::HiRes::tv_interval( $start ); #debug ("Elapsed: $elapsed seconds");
print "\n<BR>\n";
print "החיפוש לקח: $elapsed\n";
print "שניות<br>\n";
exit 0;

#################################################################################
sub trim {
    #usage: $string = trim($string);   or    @many   = trim(@many);
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

################################################################	
sub remove_nikud{
	my $word = shift;   	    

	my $sheva=pack "C2",0xD6 ,0xB0;	my $hataf_segol=pack "C2",0xD6 ,0xB1;	my $hataf_patach=pack "C2",0xD6 ,0xB2;
	my $hataf_kamatz=pack "C2",0xD6 ,0xB3;	my $chirik=pack "C2",0xd6,0xb4;	my $tsere=pack "C2",0xD6 ,0xB5;
	my $segol=pack "C2",0xD6 ,0xB6;	my $patach=pack "C2",0xd6,0xb7;	my $kamatz=pack "C2",0xd6,0xb8;
	my $left_shin =pack "C2",0xd7,0x82;	my $right_shin =pack "C2",0xd7,0x81;	my $holam =pack "C2",0xd6,0xb9;
	my $dagesh =pack "C2",0xd6,0xbc;	my $qubuts=pack "C2",0xD6 ,0xBB;

    $word =~ s/$sheva//g;	$word =~ s/$hataf_segol//g;	$word =~ s/$hataf_patach//g;
	$word =~ s/$hataf_kamatz//g;	$word =~ s/$chirik//g;	$word =~ s/$tsere//g;
	$word =~ s/$segol//g;	$word =~ s/$patach//g;	$word =~ s/$kamatz//g;
	$word =~ s/$left_shin//g;	$word =~ s/$right_shin//g;	$word =~ s/$holam//g;
	$word =~ s/$dagesh//g;	$word =~ s/$qubuts//g;	
	return $word;
}

