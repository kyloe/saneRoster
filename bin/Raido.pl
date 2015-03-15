#!/usr/bin/perl

use CGI;
use WWW::Mechanize;
use HTML::TreeBuilder;
use Kyloe::Raido::Connector;
 
 
my $calendars  = 
	{
		'Ian Bottomley' =>  {staffid => 115, password => 'test',checkin=>'yes',altsummary=>['CODE'],summary=>['CODE',' ','DEP','-','ARR']},
		'Jamie McDonald' =>  {staffid => 101, password => 'test',checkin=>'yes',altsummary=>['CODE'],summary=>['CODE',' ','DEP','-','ARR']},
     	'Murray Gibbons' =>  {staffid => 117, password => '117',altsummary=>['CODE'],summary=>['DEP','-','ARR']}
	};
  
foreach $name (keys %$calendars)  
	{

	my $raido = Kyloe::Raido::Connector->new();
	
	$raido->login($calendars->{$name}->{staffid},$calendars->{$name}->{password}) or die "Login failed\n";
	$raido->getRoster or die "Couldn't retrieve current roster page\n";
	$raido->getNextMonth or die "Could not retrieve next months roster\n";
	$raido->parseRoster('TREE') or die "Could not parse main roster\n";
	$raido->parseRoster('TREE_2') or die "Could not parse next months roster\n";
	
	$raido->writeICS($calendars->{$name});
	undef $raido;
	}
  






  