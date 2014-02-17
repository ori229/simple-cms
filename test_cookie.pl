#! /usr/bin/perl
use strict; # can be viewed in http://il-aleph07.corp.exlibrisgroup.com:8991/aleph-cgi/w/prog/test_cookie.pl
use CGI;
use CGI::Carp qw(fatalsToBrowser);

my $q=new CGI;

my $user_name ='';  my $password = '';
if (defined $q->cookie('user_and_pw')) {
    ($user_name,$password) = split('\|',$q->cookie('user_and_pw'));
    if ($q->param('user_name') ne $user_name or $q->param('password') ne $password) {
        my $del_cookie = delete_cookie($q);
        my $cookie = bake_cookie($q,$q->param('user_name'),$q->param('password'));
        print $q->header(-type => "text/html", -cookie => [$del_cookie,$cookie]);
        print "Cookie found, but params differ - deleting cookie, and creating new one<BR>";
        $user_name = $q->param('user_name');
        $password  = $q->param('password');
    } else {
        print $q->header(-type => "text/html");
        print "cookie already set for this params<BR>";
    }
} else {
    my $cookie = bake_cookie($q,$q->param('user_name'),$q->param('password'));
    print $q->header(-type => "text/html", -cookie => $cookie);
    print "no cookie found - creating new one<BR>\n";
}
 
#my %cookies = fetch CGI::Cookie;foreach my $x (keys(%cookies)) {print "$cookies{$x}".$q->br();}
    print "___cookie recieved:".$q->cookie('user_and_pw')."__\n";

print << 'EOF';
<HTML>
<HEAD>
  <META HTTP-EQUIV="Content-Type" CONTENT="text/html; CHARSET=utf-8">
</HEAD>
<BODY>
<FORM method="GET" name="myform">
EOF
print "user name: <input               name=\"user_name\" value=\"$user_name\"> <br>";
print "password:  <input type=password name=\"password\"  value=\"$password\"> ";
print << 'EOF';
    <input type="submit" name="b" value="submit">
</FORM>
</BODY>
</HTML>
EOF

exit 0;
######################
sub bake_cookie {
        my $q          = shift;
        my $user_name  = shift;
        my $password   = shift;
        my $cookie = $q->cookie(
                       -name    => "user_and_pw",
                       -value   => $user_name.'|'.$password,
                       -expires => '+24h'
        );
        return $cookie;
}
######################
sub delete_cookie {
        my $q          = shift;
        my $cookie = $q->cookie(
                       -name    => "user_and_pw",
                       -value   => '',
                       -expires => '-1d'
        );
        return $cookie;
}
