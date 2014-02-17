#!/usr/bin/perl
=pod
Can be viewed in http://smilehealth.co.il/cgi-bin/prog/w.pl

#### TODO list:
<perl></perl>    change to  <%   %>  (like PHP? JSP?)

Error messages from perl to the screen

<nowiki> like in wikipedia

"system" Page – start with "_" and in "all pages" show in <small>

Allow for all system  files to be renamed with .eng / .heb  and have a global variable $interface_lng
$lang='heb';  $global_dir='rtl';

When renaming a file name, check if it is used as a template and rename in all files.
 
CACHE: Whenever replacing a template:
<!--template start: {{big|big text}} --><BIG>big text</BIG><!--template end: {{big|big text}} -->
And then we could cache files and when a template is changed we just delete if from the cache, and in all the pages it is used, we just return the orig text
(When using cache, we need to parse the file even if it's in the cache directory). 

Support something like this:  {{big|text {{abc}} more text}}

We alredy support cache of a template used twice with the same arguments.
TODO: cache also a template without the arguments (to withhold reading the file).

In preview - don't show style which started above (how do they do it in wikipedia?)
=cut

########################################################################
use strict;
use Time::HiRes;   # only used for profiling (checking performance)
my $start = [ Time::HiRes::gettimeofday() ];  my $elapsed=0;

use CGI;
use CGI::Cookie;
use CGI::Carp qw(fatalsToBrowser);

BEGIN { # add /home/smilehea/perl to the include path:
    my $homedir = ( getpwuid($>) )[7];
    my @user_include;
    foreach my $path (@INC) {
        if ( -d $homedir . '/perl' . $path ) {
            push @user_include, $homedir . '/perl' . $path;
        }
    }
    unshift @INC, @user_include;
}
#use Log::Log4perl qw(:easy);
#    Log::Log4perl->init("log.conf");

###############################
# Constants:
my $BASE_URL = $ENV{'SCRIPT_URI'}.'?';
my $noshow = 'לאלהציג';

my $q=new CGI;

my $action = 'view';
if (defined $q->param('action')) {
    $action = $q->param('action');
}

my $type = 'regular';
if (defined $q->param('type')) {
    $type = $q->param('type');
}

#if ($action eq 'view_short_url') {
#    my $page_name = from_url( $q->param('title') );
#    print $q->header(-charset=>'utf-8');
#    print &get_line( "{{redirect_page|$page_name}}" );
#    exit;
#}

my $file_name = 'main';
$file_name = 'your_file_name' if $action eq 'edit';
if (defined $q->param('title')) {
    $file_name = $q->param('title');
    $file_name=~s/ /_/g;
}
#INFO "action: $action.  file_name: $file_name";

# The following messy code handels the cookies (for username/PW) - TODO: cleanup
my $user_name = ' ';   my $password = ' ';
if ($action eq 'view') {
	print $q->header(-charset=>'utf-8');
} else {
if (defined $q->param('user_name')) {
    if (! defined $q->cookie('user_and_pw')) {
        my $cookie = bake_cookie($q,$q->param('user_name'),$q->param('password'));
        print $q->header(-charset=>'utf-8', -cookie => $cookie);
        #DEBUG "no cookie found - creating new one\n";
        $user_name = $q->param('user_name'); $password  = $q->param('password');
    } else {  # cookie recieved
        ($user_name,$password) = split('\|',$q->cookie('user_and_pw'));
        if ($q->param('user_name') ne $user_name or $q->param('password') ne $password) {
            my $del_cookie = delete_cookie($q);
            my $cookie = bake_cookie($q,$q->param('user_name'),$q->param('password'));
            print $q->header(-charset=>'utf-8',-cookie => [$del_cookie,$cookie]);
            #DEBUG "Cookie found, but params differ - deleting cookie, and creating new one";
            $user_name = $q->param('user_name'); $password  = $q->param('password');
        } else {
            print $q->header(-charset=>'utf-8');
            #DEBUG "cookie already set for this params ($user_name)";
            $user_name = $q->param('user_name'); $password  = $q->param('password');
        }
    }
} else {   # did not recieve from CGI
    print $q->header(-charset=>'utf-8');
    if (defined $q->cookie('user_and_pw')) {
        ($user_name,$password) = split('\|',$q->cookie('user_and_pw'));
        #DEBUG "not recieve from CGI,   but found from cookie";
    } else {
        #DEBUG "did not recieve from CGI and not from cookie";
    }
}

# Test if username/PW are correct:
if ($action eq 'save' or $action eq 'preview') {
    ($user_name,$password) = trim ($user_name,$password);
    if ($user_name.$password eq 'orimPASSWORDHERE' or $user_name.$password eq 'natiPASSWORDHERE') {
        #DEBUG "Username and PW OK  :)";
    } else {
        #DEBUG "Username and PW wrong  :(";
        print "Wrong user name ($user_name) or password ($password)\n";
        exit;
    }
}
}

# Main actions:
&view('n') if $action eq 'view';  # "n" means that the view() function is not called from preview().
&edit      if $action eq 'edit';
&save      if $action eq 'save';
&preview   if $action eq 'preview';  # save .preview file, and run both &view and &edit
&cancel    if $action eq 'cancel';   # cancel editing - delete .preview file

$elapsed = Time::HiRes::tv_interval( $start ); #INFO "Elapsed: $elapsed seconds"; DEBUG "";

exit 0;
##################################################################


##################################################################
sub get_line {
    my $in_line = shift; 
    $in_line =~ s/<$noshow.*?$noshow>//gs;  # remove <noshow>...</noshow>
    ##TRACE "&get_line was called with in_line: $in_line";
    ##TRACE "  Changin [[|]] to [[~]]";
	$in_line =~ s/\[\[(.+?)\|(.+?)\]\]/[[$1~$2]]/g;
	# $in_line =~ s/\[\[(.+?)\|(.+?)\]\]/[[$1]]/g;
    #TRACE "  After change                   :$in_line";
    my $out_line = $in_line;
    my %templates_cache;  # this caches a call to a template with the same arguments  {{big|abc..}}

    while ($in_line=~m/{{(.*?)}}/gx ) {  # we don't support something like this: {{big|text {{abc}} more text}}

        my $template_string = $1;
        my @arguments = split('\|',$template_string);
        my $page_to_read = shift @arguments;

        my $in_file = "../html/$page_to_read.htm";  $in_file=~s/ /_/g;

        if (defined $templates_cache{$template_string}) {
            $out_line =~ s/\Q{{$template_string}}/$templates_cache{$template_string}/;
            #DEBUG "template \"$template_string\" found in cache";
        } else {
            #DEBUG "template \"$template_string\" not found in cache - reading file: $page_to_read";
          # Recursive calls to this function. To fill all inner templates:
          if (-f $in_file) {
            open( my $fh, $in_file ) or die "cannot open file $in_file $!\n";
            #DEBUG "Reading file: $in_file";
            my $text = do { local( $/ ) ; <$fh> } ;
            close ($fh);
            $text =~ s/<$noshow.*?$noshow>//gs;  # remove <noshow>...</noshow>


            # Replace arguments (if any exists):
            my $arg_num = 1;
	    #TRACE "  Before replace arguments: $text";
            foreach my $arg_text (@arguments) {
	        #TRACE "  Replacing \"$arg_num\" with \"$arg_text\"";
                $text =~ s/\Q{{$arg_num}}/$arg_text/g;
                $arg_num++;
            }
	    #TRACE "  After  replace arguments: $text";

	    #if ($text=~/{{/) {  # if there are more templates within....
                $text = &get_line($text);   # recurse...
	    #}

            $templates_cache{$template_string} = $text;
            $out_line =~ s/\Q{{$template_string}}/$text/;
          } else {
            # File not found
            #DEBUG "Cannot locate file: $in_file";
          }
        }
    }

    # run embedded perl code     (e.g. <perl>return "from perl";</perl> )
    while ($in_line=~m/<perl>(.*?)<\/perl>/gs ) {   # /s makes . cross line boundaries
        my $perl_code = $1;
	##TRACE "Runing perl: $perl_code";
        my $code_output = eval ($perl_code);    #if ( $@ )  { DEBUG "error: $@"};
	#TRACE "Output perl: $code_output";
        $out_line =~ s/\Q<perl>$perl_code<\/perl>/$code_output/;
    }
    return $out_line;
}

##########################################
# '''bold text'''
# ==Heading level 2==
# [[link inside the site]]  and [[page name|some text]]
sub wiki_tags {
    my $input = shift;
    $input =~ s/'''(.*?)'''/<B>$1<\/B>/gs;
    $input =~ s/\n==(.*?)==/<H2 id="$1">$1<\/H2>/gs;

    #TRACE " * Creating links from [[link inside the site]]";
    $input =~ s/\[\[([^\|\~]*?)\]\]/my $p=$1; my $orig=$1; $p=~s| |_|g; "<a title=\"$p\" href=\"$BASE_URL"."action=view&title=$p\" class=\"inner_link\">$orig<\/a>";/gse;

    #TRACE " * Creating links from [[page name|some text]]";
    $input =~ s/\[\[(.*?)[\|\~](.*?)\]\]/my $nametext=$2; my $p=$1; my $orig=$1; $p=~s| |_|g; "<a title=\"$p\" href=\"$BASE_URL"."action=view&title=$p\" class=\"inner_link\">$nametext<\/a>";/gse;

    ##########################
    # color in red dead links:
    my $input_backup = $input;
    while ($input =~ m/(<a title=.*? href=\".action=view.title=(.*?)\" class=\"inner_link\">.*?<\/a>)/gs) {
	my $lll = $1; my $lll_save = $lll;
	my $fff = $2;
	if (-f "../html/$fff.htm") {
	    ##TRACE " The link leads to a file which exists (\"$fff\") - good";
	} else {
	    #TRACE " Link to a file which does not exists (\"$fff\") - color in pink";
	    $lll=~s/a /a style="color:pink;" /;
	    #TRACE " Replacing: \"$lll_save\"";
	    #TRACE "      with: \"$lll\"";
	    $input_backup=~s/\Q$lll_save/$lll/;
	}
    }
    $input = $input_backup;
    #######################

    return $input;
}

################################################################
sub view {
    my $from_preview = shift; # regular view:n  from preview:y
    my $in_file = "../html/$file_name.htm";
    if ($from_preview eq 'y'  &&  -f "$in_file.preview") {
        $in_file.=".preview";
    }
    if ($from_preview eq 'n') {
	# increment the counter when the page is view regularly (for statistics)
        &inc_counter($file_name);
    }
    if (-f $in_file) {
        open( my $fh, $in_file ) or die "cannot open file $in_file $!\n";
        my $text = do { local( $/ ) ; <$fh> } ;
        close ($fh);

	$text = &remove_header_and_footer($text) if $type eq 'ajax';

        my $final_output = &get_line($text);

        #$final_output =~ s/<!--.*?-->//gs;  # remove HTML comments (visible in edit mode)

        $final_output = &wiki_tags($final_output);

        print $final_output;
	exit if $type eq 'ajax';

        my $editing_url = "$BASE_URL".'title='.$file_name.'&action=edit';
        print &get_line("{{small_edit_button|$editing_url}}");
    } else {
        print '<center><a href="?action=view&title=%u05E2%u05DE%u05D5%u05D3_%u05E8%u05D0%u05E9%u05D9">main page</a><center><br><br>';
        print "<small>The file <b>$file_name</b> does not exist. Press";
        print "\n<a href=$BASE_URL".'title='.$file_name.'&action=edit>Here</a> to create it</small>';
    }
}

###############################################################
sub edit {
    my $in_file = "../html/$file_name.htm";
    if (-f "$in_file.preview") {
        $in_file.=".preview";
    }

    $file_name =~ s/_/ /g;

    # Edit existing file:
    if (-f $in_file) {
        open( my $fh, $in_file ) or die "cannot open file $in_file $!\n";
        my $text = do { local( $/ ) ; <$fh> } ;
        close ($fh);

        print &get_line("{{edit_page_0|$file_name}}");

        my $out_templates_links = '';   my %all_templates;
        while ($text=~m/{{(.*?)}}/gx ) {
            my $template_string = $1;
            my @arguments = split('\|',$template_string);
            my $template = shift @arguments;
            if ($template !~ /^\d+$/) {
                next if defined $all_templates{$template};
                $all_templates{$template} = 'written';
                my $template_no_spaces = $template; $template_no_spaces=~s/ /_/g;
                my $does_not_exists = 'לא נוצרה';
                $out_templates_links.=" ($does_not_exists:)" if ! (-f "../html/$template_no_spaces.htm");
                $out_templates_links.= "\n<a href=$BASE_URL".'title='.$template_no_spaces.'&action=edit>'.$template.'</a>, ';
            }
        }
        if ($out_templates_links ne '') {
            print &get_line("{{template_list_for_editing}}");
            print "$out_templates_links\n<hr>\n";
        }

        print &get_line("{{edit_page_1|$file_name}}");
        print htmlspecialchars($text);
        print &get_line("{{edit_page_2|$file_name|$user_name|$password}}");
    } else {
    # Create new file:
        print &get_line("{{edit_page_0|$file_name}}");
        print &get_line("{{edit_page_1|$file_name}}");
        print &get_line('{{example_empty_page}}');
        print &get_line("{{edit_page_2|$file_name|$user_name|$password}}");
    }
}

################G############################################
sub save {
    my $all_text = "<br>No text entered.<br>\n";
    if (defined $q->param('action')) {
        $all_text = $q->param('all_text');
    }

   (my $SEC, my $MIN, my $HOUR, my $DAY,my $MONTH,my $YEAR) =
         (localtime)[0,1,2,3,4,5]; $MONTH+=1; $YEAR+=1900;
    my $now = sprintf("%04d%02d%02d_%02d%02d%02d",$YEAR,$MONTH,$DAY,$HOUR,$MIN,$SEC);

    my $out_file = "../html/$file_name.htm";

    if (-f $out_file) {
        # Renaming the file before change:
        rename($out_file,"../html/cvs/$file_name.htm.$now.$user_name") or die "cannot move to ../html/cvs/\n";
    }

    open  (OUT_F, ">$out_file") or die "Cannot open $out_file as output\n" ;
    print  OUT_F  $all_text;
    close (OUT_F);
    unlink ("$out_file.preview");

    print &get_line("{{after_save|$BASE_URL|$file_name}}");
}

############################################################
sub preview {
    my $all_text = "<br>No text entered.<br>\n";
    if (defined $q->param('action')) {
        $all_text = $q->param('all_text');
    }

    my $out_file = "../html/$file_name.htm.preview";

    open  (OUT_F, ">$out_file") or die "Cannot open $out_file as output\n" ;
    print  OUT_F  $all_text;
    close (OUT_F);

    &view('y');
    print "<BR><BR><HR><CENTER>* * *</CENTER><HR>";
    &edit();
}

############################################################
sub cancel {
    #DEBUG "Cancel Editing. Deleting ../html/$file_name.htm.preview (if it exists)";
    unlink ("../html/$file_name.htm.preview");
    #DEBUG "Redirecting back to $file_name";
    print &get_line("{{after_save|$BASE_URL|$file_name}}");
}

##################################
sub htmlspecialchars {
    my ($string) = @_;
    $string=~s/&/&amp;/g;
    $string=~s/'/&#039;/g;
    $string=~s/"/&quot;/g;
    $string=~s/</&lt;/g;
    $string=~s/>/&gt;/g;
    return $string;
}
sub htmlspecialchars_decode {
    my ($string) = @_;
    $string=~s/&amp;/&/g;
    $string=~s/&apos;/'/g;
    $string=~s/&#039;/'/g;
    $string=~s/&quot;/"/g;
    $string=~s/&lt;/</g;
    $string=~s/&gt;/>/g;
    return $string;
}

##################################
sub bake_cookie {
        my $q          = shift;
        my $user_name  = shift;
        my $password   = shift;
        my $cookie = $q->cookie(
                       -name    => "user_and_pw",
                       -value   => $user_name.'|'.$password,
                       -expires => '+94h'
        );
        return $cookie;
}
sub delete_cookie {
        my $q          = shift;
        my $cookie = $q->cookie(
                       -name    => "user_and_pw",
                       -value   => '',
                       -expires => '-1d'
        );
        return $cookie;
}

###################################
sub inc_counter {
    my $name_of_page = shift;
    my $in_file = "../logs/$name_of_page.counter";
    if (-f $in_file) {
        open( my $fh, $in_file ) or return "cannot open file $in_file $!\n";
        my $text = do { local( $/ ) ; <$fh> } ;
        close ($fh);
        $text +=1;
        open  (OUT_F, ">$in_file") or return "Cannot open $in_file as output\n" ;
        print OUT_F $text;
        close (OUT_F);
    } else {
        open  (OUT_F, ">$in_file") or return "Cannot open $in_file as output\n" ;
        print OUT_F "1";
        close (OUT_F);
    }
}

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

################################################################################
sub remove_header_and_footer {
    my $in = shift;
    # $in =~ s/^\w*{{.*?}}//s;
    $in =~ s/{{כותרת עילית}}//;
    # $in =~ s/{{.*?}}\w*$//s;
    $in =~ s/{{כותרת תחתית}}//;
    #DEBUG "Removed header and footer do to an AJAX request";
    return $in;
}
