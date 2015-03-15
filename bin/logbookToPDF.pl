#!/usr/bin/perl

use PDF::Report;
use DBI;

use strict;
use warnings;

sub boxedWord($$$$$);
sub boxedWordMultiRow($$$$$$);
sub throwPage($$);
sub totalRow($);

# Command line for Jan 2012 should be perl logbook.pl 01 2012 

if (!$ARGV[2])	
	{
	die "Usage: (perl) $0 staffnumber mm yyyy\n";
	}

my $staffNumber	= $ARGV[0];
my $month 	= $ARGV[1];
my $year 	= $ARGV[2];

if (length($month) == 1)
	{
	$month = "0".$month;
	}

our $monthName   = {'01'=>"Jan",'02'=>"Feb",'03'=>"Mar",'04'=>"Apr",'05'=>"May",'06'=>"Jun",'07'=>"Jul",'08'=>"Aug",'09'=>"Sep",'10'=>"Oct",'11'=>"Nov",'12'=>"Dec",};

my $filename = "Logbook_".$staffNumber."_".$year."_".$month.".pdf";

my $pdf = new PDF::Report(PageSize => "A4", 
                          PageOrientation => "Landscape");
 
# Psuedo code
#
# Get data set
# while not end of data
# 	add a page
# 	output header info
# 	output table header row
# 	while not end of data and not end of page
# 		output row
#		next row
#	endwhile
# 	output footers
# endwhile
# save file
# report
# 

#############################################################################################################################
# Get data set
#############################################################################################################################

my $dbh = DBI->connect("dbi:Pg:dbname=raido;user=raido;password=raido") or die "Could not connect to database";

my $sqlString = <<ENDSQL; 

select 
	to_char(date,'DD/MM/YY')	as 	Date, 
	dep 				as 	From, 
	to_char(dep_time,'HH24:MI') 	as 	DTime, 
	arr 				as 	To,
	to_char(arr_time,'HH24:MI') 	as 	ATime , 

	type 				as 	type, 
	reg 				as 	reg, 
	se 				as 	se, 
	me 				as 	me, 
	multicrew 			as 	multicrew, 

	hrs_block 			as 	hrs_block, 

	capt 				as 	capt, 

	land_day 			as 	day, 
	land_night 			as 	night, 

	hrs_night 			as 	hrs_night, 
	hrs_ifr 			as 	hrs_ifr,  
	hrs_pic				as 	hrs_pic,
	hrs_copilot 			as	hrs_copilot, 
	hrs_dual 			as	hrs_dual, 
	hrs_instruction 		as 	hrs_instruction, 
	hrs_sim 			as 	hrs_sim,
	sim_type 			as 	sim_type,
	sim_reg 			as 	sim_reg,

	comments 			as 	remarks 
	from log_raw

ENDSQL

my $sqlSumString = <<ENDSUMSQL; 

select 
	'&nbsp;'			as 	col1, 
	'&nbsp;' 			as 	col2, 
	'&nbsp;' 			as 	col3, 
	'&nbsp;' 			as 	col4,
	'&nbsp;' 			as 	col5 , 
	'&nbsp;' 			as 	col6, 
	'&nbsp;' 			as 	col7, 
	'&nbsp;' 			as 	col8, 
	'&nbsp;' 			as 	col9, 
	'&nbsp;' 			as 	col10, 
	sum(hrs_block) 			as 	sum_hrs_block, 

	'&nbsp;' 			as 	capt, 

	sum(land_day) 			as 	sum_day, 
	sum(land_night) 		as 	sum_night, 

	sum(hrs_night) 			as 	hrs_night, 
	sum(hrs_ifr)			as 	hrs_ifr,  
	sum(hrs_pic)			as 	hrs_pic,
	sum(hrs_copilot) 		as	hrs_copilot, 
	sum(hrs_dual) 			as	hrs_dual, 
	sum(hrs_instruction) 		as 	hrs_instruction, 
	sum(hrs_sim) 			as 	hrs_sim,
	'&nbsp;' 			as 	sim_type,
	'&nbsp;' 			as 	sim_reg,

	'&nbsp;' 			as 	remarks 
	from log_raw

ENDSUMSQL

my $sqlTotString = $sqlSumString;
my $sqlPrevTotString = $sqlSumString;
my $start_dt = $year.'-'.$month.'-01';	

$sqlString = 	$sqlString . 		" where date >= '".$start_dt."' and date <= date '".$start_dt."' + interval '1 month' - interval '1 day' ";
$sqlTotString = $sqlSumString . 	" where date <= date '".$start_dt."' + interval '1 month' - interval '1 day'";
$sqlPrevTotString = $sqlSumString . 	" where date <  '".$start_dt."'";
$sqlSumString = $sqlSumString . 	" where date >= '".$start_dt."' and date <= date '".$start_dt."' + interval '1 month' - interval '1 day'";

$sqlString = 	$sqlString . 		" and staff_id = ".$staffNumber;
$sqlTotString = $sqlTotString . 	" and staff_id = ".$staffNumber;
$sqlPrevTotString = $sqlPrevTotString . " and staff_id = ".$staffNumber;
$sqlSumString = $sqlSumString . 	" and staff_id = ".$staffNumber;


my @name;

@name = $dbh->selectrow_array("SELECT name from person where staff_id  = ".$staffNumber)
	or die "Could not retrieve name for staff_id = ".$staffNumber;			

#########################################################################################################################
# while not end of data
#########################################################################################################################

my $x_start = 10;
my $y_start = 540;
my $max_rows_on_page = 40;
my $rows_on_page = 0;
my $cur_x_pos = $x_start;
my $cur_y_pos = $y_start;
my $row_ref = 1;

my $formatter = sub 
	{
	$_=shift;
	if ($_)
		{
		sprintf("%02d:%02d",int($_),($_-int($_))*60);
		}
	else
		{
		sprintf("__:__");
		}
	};


our $rowDefinition = 
	[
	{header=>'Date' ,orientation=>0,width=>30,sample=>'12/12/99'},
	{header=>'From' ,orientation=>0,width=>16,sample=>'GLA'},
	{header=>'Time' ,orientation=>0,width=>20,sample=>'10:55'},
	{header=>'To'   ,orientation=>0,width=>16,sample=>'SYY'},
	{header=>'Date' ,orientation=>0,width=>20,sample=>'12:01'},
	{header=>'Type' ,orientation=>0,width=>21,sample=>'SF340'},
	{header=>'Reg'  ,orientation=>0,width=>28,sample=>'GLGNM'},
	{header=>'SE'   ,orientation=>0,width=>10,sample=>'X'},
	{header=>'ME'   ,orientation=>0,width=>10,sample=>'X'},
	{header=>'Mu'   ,orientation=>0,width=>10,sample=>'X'},
	{header=>'Hrs'  ,orientation=>0,width=>26,sample=>'4320:00',parser=>$formatter,totalled=>'Yes'},
	{header=>'Capt' ,orientation=>0,width=>60,sample=>'BOTTOMLEY Ian'},
	{header=>'D'    ,orientation=>0,width=>18,sample=>'1000',totalled=>'Yes'},
	{header=>'N'    ,orientation=>0,width=>18,sample=>'200',totalled=>'Yes'},
	{header=>'Night',orientation=>0,width=>26,sample=>'1234:00',parser=>$formatter,totalled=>'Yes'},
	{header=>'IFR'  ,orientation=>0,width=>26,sample=>'1111:00',parser=>$formatter,totalled=>'Yes'},
	{header=>'PIC'  ,orientation=>0,width=>26,sample=>'1340:22',parser=>$formatter,totalled=>'Yes'},
	{header=>'Co'   ,orientation=>0,width=>26,sample=>'9999:99',parser=>$formatter,totalled=>'Yes'},
	{header=>'Dual' ,orientation=>0,width=>26,sample=>'9999:99',parser=>$formatter,totalled=>'Yes'},
	{header=>'Inst' ,orientation=>0,width=>26,sample=>'9999:99',parser=>$formatter,totalled=>'Yes'},
	{header=>'Sim'  ,orientation=>0,width=>20,sample=>'8888.88',parser=>$formatter,totalled=>'Yes'},
	{header=>'Type' ,orientation=>0,width=>21,sample=>'SF340'},
	{header=>'Reg'  ,orientation=>0,width=>30,sample=>'XXYYZZ'},
	{header=>'Remarks',orientation=>0,width=>250,sample=>'Here there will be complex text listing many gripes and grumbles'}

	];

# Prepare main data panel query
	
my $results = $dbh->selectall_arrayref($sqlString)
	or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;

my $maxRows  = 40;
my $rowCount = 0;
	

foreach my $row (@$results)
	{
	
	if ($rowCount < 1)
		{
		$cur_y_pos = $y_start;
		($cur_x_pos,$cur_y_pos) = throwPage($cur_x_pos,$cur_y_pos);
		$rowCount=$maxRows;
		}
	
	$cur_x_pos = $x_start;
	
	my $i = 0;

	# remarks are last field - need to calc text size to see how deep to make row
	
	my $rowsRequired = 1;
	
	if ($row->[-1])
		{
		$rowsRequired = int(length($row->[-1])/62)+1;
		}

	
	foreach my $field (@$row)
		{
		# translate field if required
		if (@$rowDefinition[$i]->{parser})
			{
			$field = @$rowDefinition[$i]->{parser}->($field);
			}
		boxedWordMultiRow($pdf,$field,$cur_x_pos,$cur_y_pos,@$rowDefinition[$i]->{width},$rowsRequired);
		$cur_x_pos += @$rowDefinition[$i]->{width}+1;
		$i++;
		}

	$rowCount -= $rowsRequired;	

	$cur_x_pos = $x_start;
	$cur_y_pos -= 10*$rowsRequired;
	
	}

# Add totals
# Page summary 


$results = $dbh->selectrow_arrayref($sqlSumString)
	or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;

totalRow($results);
$cur_x_pos = $x_start;
$cur_y_pos -= 10;


# Previous pages summary data panel

$results = $dbh->selectrow_arrayref($sqlPrevTotString)
	or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;

totalRow($results);
$cur_x_pos = $x_start;
$cur_y_pos -= 10;


# Grand total data panel

$results = $dbh->selectrow_arrayref($sqlTotString)
	or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;

totalRow($results);
$cur_x_pos = $x_start;


# A few random labels

$cur_y_pos += 20;

boxedWord($pdf,"Totals for this page",$cur_x_pos,$cur_y_pos,190);
boxedWordMultiRow($pdf,"I certify that this a true and accurate record",563,$cur_y_pos,250,3);

$cur_y_pos -= 10;

boxedWord($pdf,"Totals from previous pages",$cur_x_pos,$cur_y_pos,190);

$cur_y_pos -= 10;

boxedWord($pdf,"Grand total",$cur_x_pos,$cur_y_pos,190);


$pdf->saveAs($filename);


sub  totalRow($)
	{
	my $results = shift;		
	my $i=0;
	foreach my $field (@$rowDefinition)
		{
		if ($field->{totalled})
			{
			my $t = $results->[$i];
			if (@$rowDefinition[$i]->{parser})
				{
				$t = @$rowDefinition[$i]->{parser}->($results->[$i]);
				}
			boxedWord($pdf,$t,$cur_x_pos,$cur_y_pos,$field->{width});
			}
		$i++;
		$cur_x_pos += $field->{width}+1;
		}
	}



sub throwPage($$)
	{
	my $cur_x_pos = shift;
	my $cur_y_pos = shift ;

	$pdf->newpage();

	print "PDF: new page\n";
	# Header stuff

	boxedWord($pdf,$name[0],$cur_x_pos,$cur_y_pos,60);
	
	$cur_y_pos -= 20;
	
	boxedWord($pdf,$monthName->{$month}." ".$year,$cur_x_pos,$cur_y_pos,60);
	
	$cur_y_pos -= 20;

	# Table header

	foreach my $field (@$rowDefinition)
		{
		boxedWord($pdf,$field->{header},$cur_x_pos,$cur_y_pos,$field->{width});
		$cur_x_pos += $field->{width}+1;
		}
	$cur_y_pos -= 10;	
	
	return ($cur_x_pos,$cur_y_pos);
	}


print "Finished: $filename\n";

sub boxedWord($$$$$)
	{
	boxedWordMultiRow(shift,shift,shift,shift,shift,1);
	}

sub boxedWordMultiRow($$$$$$)
	{
	my $pdf = shift;
	my $word = shift;
	my $x = shift;
	my $y = shift;
	my $length = shift;
	my $rows = shift;
	
	
	$pdf->setAddTextPos($x,$y);
	$pdf->setSize(7);
	$pdf->setFont("Arial");
	$pdf->drawRect($x-1,$y-2-(($rows-1)*10),$x+$length,$y+8);

	$pdf->addText($word);
	
	
	}
	

	
	

