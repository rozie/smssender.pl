#!/usr/bin/perl

# Script for sending SMS to Polish operatros via http://www.smscenter.pl/ service
# Requires: Perl, Getopt::Std and LWP::Simple modules, http://www.smscenter.pl/ account
# Usage: smssender.pl -n <number> -m "<message>" [-c config] [-t sign]
# Author: Pawe³ 'Ró¿a' Ró¿añski rozie[at]poczta(dot)onet(dot)pl
# Homepage: http://rozie.blox.pl/strony/smssender.html
# License: GPL v2.
my $Version="smssender.pl 0.91\n";

use strict;
use Getopt::Std;
use LWP::Simple;

getopt ('mctnV');
getopts ('x');

# m - message
# n - number
# t - sign
# c - config file
# x - compression (space removal)

our($opt_c, $opt_t, $opt_n, $opt_m, $opt_x);

my $configfile="$ENV{HOME}/.smssender.rc";	 # default config file
my $url="http://api.statsms.net/send.php";  	 # base URL
my $number= $opt_n;				 # number to send SMS to
my $text=$opt_m;				 # message (SMS body)
my $from="";					 # Sender ID (required(?) for mobitex, works also for redlink)
my $type="sms";					 # SMS type (sms/sms_flash/concat) - used on mobitex only
my $provider="mobitex";				 # which provider? mobitex by default
my $debug=0;					 # use debug mode?

my $sign=$opt_t;				 # sign, if not defined searches config
my $config=$opt_c;				 # path to config file
my $sign_c="";					 # sign from config file
my $type_c="";					 # SMS type from config file 
my $from_c="";					 # Sender ID (required(?) for mobitex, works also for redlink) from config file
my $user="";					 # user (from config file)
my $pass="";					 # password (from config file)
my $res="";					 # result of sending
my $final="";					 # final URL which is called (after adding user, pass etc.)
my $compress=$opt_x?1:0;                         # try to compress? (remove spaces remaining SMS readable)
my $provider_c="";				 # provider from config file

$number=~ s/^0//;	                         # cat leading zero if present
if (length($number) != 9){
	print $Version;
        die "Bad phone number (enter 9 digits + optional 0 on the beginning)\n";
}

if ($text !~ /\S/){
	die "Text message has to contain at least one non whitespace character.\n";
}

if ($config =~ /\S/){				 # use given config file
	$configfile=$config;	
}

open (CFG,"$configfile") or die "Can't open *$configfile*\n";
while (<CFG>){
	chomp;
	if (! /^\s*#/){
		if (/(user|login)=(.*)/){
			$user=$2;
		}
		elsif (/(pass|haslo|password)=(.*)/){
			$pass=$2;
		}
		elsif (/(sig|sign)=(.*)/){
			$sign_c=$2;
		}
		elsif (/(typ|type)=(.*)/){
			$type_c=$2;
		}
		elsif (/(provider|dostawca)=(.*)/){
			$provider_c=$2;
		}
		elsif (/(from|nadawca)=(.*)/){
			$from_c=$2;
		}
	}
}
close (CFG);

if ($provider_c =~/^(mobitex|redlink)$/){
	$provider=$provider_c;
	if ($provider eq "redlink"){
		$url="https://redlink.pl/services/Sms/v1/Send.aspx";
	}
}

if ($sign !~ /\S/){
	$sign=$sign_c;
}

if ($type_c =~/^(sms|sms_flash|concat)$/){	# set type if valid
	$type=$type_c;
}

if ($sign =~ /\S/){			# add sign if non-empty
	$text.=" --$sign";
}

if ($from_c){				# use from if set in config file
	$from=$from_c;
}

# check if required values are present
if ($user !~ /\S/){
	die "Enter user name in config file\n";
}
if ($pass !~ /\S/){
	die "Enter password in config file\n";
}

# compression
if ($compress){
        $text=~ s/\s([a-z])/uc($1)/ge;                  # zamiana spacja [a-z] na [A-Z]
        $text=~ s/\.\s([A-Z0-9])/.$1/g;                 # wyciecie spacji miedzy . a [A-Z0-9]
}

# sending message
print "Sending via $provider to number $number SMS with body:\n $text\n";

if ($provider eq "mobitex"){
	$number="48".$number;    	                 # add 48 (Poland) before number
	$final="\"".$url."?"."number=$number"."&text=$text"."&user=$user"."&pass=$pass"."&from=$from"."&type=$type"."\"";
}
elsif ($provider eq "redlink"){
	$number="0".$number;    	                 # add 0 before number (required by redlink)
	$final="\"".$url."?"."number=$number"."&message=$text"."&login=$user"."&password=$pass"."&sender_id=$from"."\"";
}

$res=get("$final");
die "Couldn't get result!" unless defined $res;

print "\nFull response\n$res\n" if $debug;

# result handling
# mobitex zone
if ($res =~ /Status:\s002/){            # status 002 - queued for sending
        print "SMS send OK\n";
}
elsif ($res =~ /Status:\s202/){		# status 202 - no money on account
	die "SMS delivery failed: not enough credit! $res\n";
}
elsif ($res =~ /Status:\s202/){		# status 204 - account not active
	die "SMS delivery failed: account not active! $res\n";
}
elsif ($res =~ /Status:\s001/){		# status 001 - auth error
	die "SMS delivery failed: authorization error! $res\n";
}
elsif ($res =~ /Status:\s105/){		# status 105 - text too long
	die "SMS delivery failed: text to long! $res\n";
}
elsif ($res =~ /Status:\s115/){		# status 113 - text too long (yep, same as above in API docs)
	die "SMS delivery failed: text to long! $res\n";
}
# redlink zone
elsif ($res =~ /"code"\:0,"description"\:"OK"/){
	print "SMS send OK\n";
}
else {
        die "SMS delivery failed: $res\n";
}
