package saneRoster;
use Dancer ':syntax';

use WWW::Mechanize;
use HTML::TreeBuilder;
use Date::Calc qw(Day_of_Week Week_Number Day_of_Year Add_Delta_Days);
use Data::Dumper;
use DBI;
use CGI::FormBuilder;
use Template;
use HTML::Table::FromDatabase;
use Kyloe::Raido::Connector::Logbook;
use Kyloe::Util::logbookToPDF;

use LWP;

set $CGI::LIST_CONTEXT_WARN = 0; #Gets around bug in CGI::FormBuilder::Field;

our $VERSION = '0.1';

my $menuString="<a href=/>Home</a>&nbsp;<a href=/view/115>View</a>&nbsp;<a href=/calendar>Calendar</a>";

our $dbh = DBI->connect("dbi:Pg:dbname=raido;user=raido;password=raido") or die "Could not connect to database";


my $raido = undef;

#hook 'before' => sub {
#	    if (! session('staff_id') && request->path_info !~ m{^/login}) {
#	        var requested_path => request->path_info;
#	        request->path_info('/login');
#	    }
#	 };

get '/env' => sub {
	print "Environment:".config->{environment}."\n"; #development
	print "Appdir:".config->{appdir}."\n"; #development
	print "Public:".config->{public}."\n"; #development
	
};

get '/' => sub {
	redirect '/login';    
};


get '/login' => sub
	{
	session->destroy;
		
	set layout=>'main_no_menu';

	template 'login', {form_header => '', form_footer=>'' };
	
	};

post '/login' => sub
	{

#	Get login details and validate against system db AND against RAIDO
#   user must be valid in both contexts

	if (isValidSaneRosterUser(params->{staff_id}))
		{
		my $raido = Kyloe::Raido::Connector::Logbook->new();
	
		if (1 || $raido->login(params->{staff_id},params->{password})) # Hack to speed up testing
#		if ($raido->login(params->{staff_id},params->{password}))
			{
				session staff_id => params->{staff_id};
				session password => params->{password};
			}
	
		$raido = undef;

		}


	
	
	if (session->{staff_id})
		{
			redirect '/main';
		}
		else
		{
			redirect '/login';
		}

	};


get '/preferences' => sub
{
		set layout=>'main';
		
		# Get a field list from the preferences list
		# for each field get a list of values
		# for each list of values identifiy a default
		 
		# prepare a form and deliver it
		
		my $my_staff_id = session->{staff_id};
		my $sql = qq/select "staff_id","calendarApplication","calendarFormat","email" from person where "staff_id" = $my_staff_id/;
		my $dbval = $dbh->selectrow_hashref($sql);

	    # First create our form

	    my $form = CGI::FormBuilder->new(
	                    name     => 'preferences',
	                    action   => '/preferences',
	                    method   => 'post',
	                    fields   => $dbval,
	                    validate => {
                        			email => 'EMAIL'
                    				}
	               		);
		
		$form->field(name => 'calendarApplication',
                 	 options => [qw(Google iCal Other)]);
		$form->field(name => 'staff_id',
                 	 type => 'hidden');
                 	 
         
		template 'form', {form_header => '', form_body=>$form->render(header => 0),form_footer=>'' };
};

get '/preferences2' => sub
{
		set layout=>'main';
		
		# Get a field list from the preferences list
		# for each field get a list of values
		# for each list of values identifiy a default
		 
		# prepare a form and deliver it


		# Need to select a list of services, for each service, credentials and a set of parameters 

		
		my $my_staff_id = session->{staff_id};
		my $sql = qq/select "id","name","staff_id","email" from person where "staff_id" = $my_staff_id/;
		my $dbval = $dbh->selectrow_hashref($sql);
		   $sql = qq/select pa.id as pa__id,s.name as s__name,pe.staff_id as pe__staff,pe.name as pe__name,c.username as c__username,c.password as c__password,pa.name as pa_name,pa.value as pa__value from service s,person pe,credentials c, parameters pa where c.person_id = $dbval->{id} and c.service_id = s.id and pa.credential_id = c.id/;
		my $prefs = $dbh->selectall_hashref($sql,'pa__id');

	    # First create our form
		
		my $fields->{name} = $dbval->{name};
		my $fields->{email} = $dbval->{email};
		my $fields->{calendarApplication} = $dbval->{calendarApplication};
				debug Dumper($prefs);

		my $pref_counter = 0;
		foreach my $pref ($prefs)
			{
			$fields->{$pref->{name}.'_'.$pref_counter} = $pref->{value};
			$pref_counter++;	
			}

	    my $form = CGI::FormBuilder->new(
	                    name     => 'preferences',
	                    action   => '/preferences',
	                    method   => 'post',
	                    fields   => $fields,
	                    validate => {
                        			email => 'EMAIL'
                    				}
	               		);
		
		$form->field(name => 'calendarApplication',
                 	 options => [qw(Google iCal Other)]);
		$form->field(name => 'staff_id',
                 	 type => 'hidden');
                 	 
         
		template 'form', {form_header => '', form_body=>$form->render(header => 0),form_footer=>'' };
};



post '/preferences' => sub
	{
	set layout => 'main';
	
	my $calApp = param "calendarApplication";
	my $calFormat = param "calendarFormat";
	my $email = param "email";
	my $staff_id = param "staff_id";
	
	my $sql = qq/update person set "calendarApplication" = '$calApp', "calendarFormat" = '$calFormat', "email" = '$email' where "staff_id" = '$staff_id'  /;
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	# my ($result) = $sth->fetchrow;
	
	template 'form', {form_header => '', form_body=>bannerMessage('Preferences updated'),form_footer=>'' };
	};

get '/scrape' => sub 	
	{
		set layout=>'main';

		
		# Get a field list from the preferences list
		# for each field get a list of values
		# for each list of values identifiy a default
		 
		# prepare a form and deliver it
		
#		my $my_staff_id = session->{staff_id};
#		my $sql = qq/select "staff_id","calendarApplication","calendarFormat","email" from person where "staff_id" = $my_staff_id/;
#		my $dbval = $dbh->selectrow_hashref($sql);


		my $my_staff_id = session->{staff_id};
		my $sql = qq/SELECT to_char(current_date,'DD\/MM\/YYYY') as todays_date,to_char(max(sector_date)+1,'DD\/MM\/YYYY') as last_date FROM sector, person where sector.logbook_id = person.id and person.staff_id = '$my_staff_id'/;
		my $sth = $dbh->prepare($sql) or die "Couldn't prepare max date select statement: " . $dbh->errstr;

		$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;

		my $start_date_result = $sth->fetchrow_hashref();


		my @fields = qw(startdate enddate);

		my $form = CGI::FormBuilder->new(
			    fields => \@fields,
			    header => 0,
			    method => 'post',
			    action => '/scrape', 
			    title => 'Log in',
			    # disabled => 1,
			    validate => 
				{
				startdate  => 'EUDATE',
				enddate  => 'EUDATE'
				}
		       );

		$form->field('startdate',class=>'date',value=>$start_date_result->{last_date});
		$form->field('enddate',class=>'date',value=>$start_date_result->{todays_date});
              	 
         
		template 'form', {form_header => '', form_body=>$form->render(header => 0),form_footer=>'' };	
	};
	
post '/scrape' => sub 	
	{
		# Need to login to raido again

	my $raido = Kyloe::Raido::Connector::Logbook->new();

	if (!$raido->login(session->{staff_id},session->{password}))
		{
		redirect '/login';
		}

	# scrape all the data
	# store in memory
	# arrange

	$raido->getRaidoData(param('startdate'),param('enddate'),session->{staff_id},$dbh);
	
	# push in to database 

	my $result = 'Data for the period '.param('startdate').' to '.param('enddate').' has been retrieved and stored.';
	
	$raido = undef;	
	
#	template 'form', {form_header => '', form_body=>bannerMessage('Your log book has been updated'),form_footer=>'' };	
	template 'form', {form_header => '', form_body=>bannerMessage($result),form_footer=>'' };		
	};
	
get '/pdf/:filename' => sub
	{
		my ($year,$month) = splat;
		return send_file('/pdf/'.session('staff_id').'/'.params->{filename});
	};
	
get '/main' => sub
	{			
		set layout=>'main';
		template 'index', {staff_id => session->{staff_id} , form_header => '', form_footer=>'' };
	};


#
# Browse data
#

get '/view/*' => sub
	{
				debug "BROWSE";
		debug Dumper($dbh);
		
	my ($id) = splat;
	forward "/view/$id/menu",{}, { method => 'GET' };
	};

get '/view/*/*' => sub
	{
	my ($id,$format) = splat;
	my ($m, $y) = (localtime)[4,5];
	$m += 1;
	$y += 1900;
	forward "/view/$id/$format/$y/$m",{}, { method => 'GET' };
	};


get '/view/*/*/*/*' => sub
	{
	my ($id,$format,$year,$month) = splat;
	my $lastYear;
	my $nextYear;
	my $lastMonth;
	my $nextMonth;
	my $menuString;


	my $sth = $dbh->prepare("Select name from person where staff_id=$id")
		or die "Failed to prepare query - " . $dbh->errstr;
	
	$sth->execute() 
		or die "Failed to execute query - " . $dbh->errstr;


	my @name = $sth->fetchrow_array();

	
	if ($month == 1)
		{
		$lastMonth = 12;
		$lastYear = $year - 1;
		}
	else 
		{
		$lastMonth = $month - 1;
		$lastYear = $year;
		}

	if ($month == 12)
		{
		$nextMonth = 1;
		$nextYear = $year + 1;
		}
	else 
		{
		$nextMonth = $month + 1;
		$nextYear = $year;
		}
	
	set layout=>'main';

	if($format eq 'menu')
		{
#		$menuString = "<center><table width=70%><tr><td width=80px><div id='button'><a href='/view/$id/$format/$lastYear/$lastMonth'>prev<a/></div></td><td width=80px><div id='button'><a href='/view/$id/$format/$nextYear/$nextMonth'>next<a/></div>	</td></tr></table></center>" 
		$menuString = "<div id='buttonBar'><div id='buttonBarLeft'><div id='button'><a href='/view/$id/$format/$lastYear/$lastMonth'>prev<a/></div></div><div id='buttonBarRight'><div id='button'><a href='/view/$id/$format/$nextYear/$nextMonth'>next<a/></div></div></div>" 

		}

	my $monthPadded = $month;
	$monthPadded = '0'.$month if ($month < 10);

	my $pdfFileName =  '/pdf/'.session('staff_id').'/Logbook_'.session('staff_id').'_'.$year.'_'.$monthPadded.'.pdf';

	my $data = retrieveMonthView($year,$month,$id);


 	my $link = 'No PDF available';

	if (-e config->{appdir}.config->{pubdir}.$pdfFileName)
		{
		$link = '<a href='.$pdfFileName.'>Download</a>' ; 
		}

	template 'view_log_book.tt',   
		{
		form_header => "Logbook:$name[0]<br /><br />".$menuString,
		form_body => $data,
		pdf_link => $link,
		form_footer=>$menuString
		};
	};


my $shortner = sub
	{
	my $text = shift;
	$text = '' unless ($text);
	return "<a class=\"tooltip\" href=\"#\">".substr($text,0,48)." ... <span class=\"classic\">".$text."</span></a>";
	};


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


sub bannerMessage()
{
	return '<div id="bannerMessage">'.shift.'</div>';
}

sub isValidSaneRosterUser()
	{
	my $id = shift;
	
	my $sth = $dbh->prepare(qq/Select "saneRosterUser" from person where staff_id=$id/)
		or die "Failed to prepare query - " . $dbh->errstr;
	
	$sth->execute() 
		or die "Failed to execute query - " . $dbh->errstr;


	my $name = $sth->fetchrow_hashref();
	
	if ($name->{saneRosterUser} eq 'Y')
		{
		return 1;
		}
	return 0;
	}


sub retrieveMonthView()
	{
	my $year = shift;
	my $month = shift;
	my $id = shift;

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
	my $sth;
	my @name;

	my $start_dt = $year.'-'.$month.'-01';
	

	$sqlString = 	$sqlString . 		" where date >= '".$start_dt."' and date <= date '".$start_dt."' + interval '1 month' - interval '1 day' ";
	$sqlTotString = $sqlSumString . 	" where date <= date '".$start_dt."' + interval '1 month' - interval '1 day'";
	$sqlPrevTotString = $sqlSumString . 	" where date <  '".$start_dt."'";
	$sqlSumString = $sqlSumString . 	" where date >= '".$start_dt."' and date <= date '".$start_dt."' + interval '1 month' - interval '1 day'";

	$sqlString = 	$sqlString . 		" and staff_id = ".$id;
	$sqlTotString = $sqlTotString . 	" and staff_id = ".$id;
	$sqlPrevTotString = $sqlPrevTotString . " and staff_id = ".$id;
	$sqlSumString = $sqlSumString . 	" and staff_id = ".$id;

	@name = $dbh->selectrow_array("SELECT name from person where staff_id  = ".$id)
		or die "Could not retrieve name for staff_id = ".$id;			
	
		
	# Prepare main data panel
	
	$sth = $dbh->prepare($sqlString)
		or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;
	
	$sth->execute() 
		or die "Failed to execute query - " . $dbh->errstr . " : ".$sqlString;


	my $header_names = ['Date','From','Time','To','Time','Type','Reg','SE','ME','Multi','Hrs','Capt.','D','N','Night','IFR','PIC','Copilot','Dual','Instr','SimHrs','SimType','Reg','Remarks'];
		
	my $table = HTML::Table::FromDatabase->new( 	-sth => $sth,
							-evenrowclass => 'even_row',
                            				-oddrowclass => 'odd_row',
                            				-override_headers=>$header_names,
                            				-spacing=>0,
                            				-padding=>'1px',
                            				-class=>'logbookTable',
                            				-callbacks=> 
                            					[
                            						{ 
                            							column => 'hrs_block',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_night',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_ifr',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_pic',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_copilot',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_dual',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_instruction',
                            							transform => $formatter,
                            						},
                            						{ 
                            							column => 'hrs_sim',
                            							transform => $formatter,
                            						},
                             						{ 
                            							column => 'remarks',
                            							transform => $shortner,
                            						},
                            					],
                            				);

	# Assign a class to each col so we can set col widths in css
	
	my $i=1;

	foreach my $header_name (@$header_names)
		{
		$table->setColClass($i,$header_name."_class");
		$i++;
		}


	my $baseTableRows = $table->getTableRows();# stash num rows before we start adding totals
	
	# Page summary data panel

	$sth = $dbh->prepare($sqlSumString)
		or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;
	
	$sth->execute() 
		or die "Failed to execute query - " . $dbh->errstr . " : ".$sqlString;


	$table->addRow($sth->fetchrow_array());

	# Previous pages summary data panel

	$sth = $dbh->prepare($sqlPrevTotString)
		or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;
	
	$sth->execute() 
		or die "Failed to execute query - " . $dbh->errstr . " : ".$sqlString;


	$table->addRow($sth->fetchrow_array());

	# Grand total data panel
	
	$sth = $dbh->prepare($sqlTotString)
		or die "Failed to prepare query - " . $dbh->errstr . " : ".$sqlString;
	
	$sth->execute() 
		or die "Failed to execute query - " . $dbh->errstr . " : ".$sqlString; 


	$table->addRow($sth->fetchrow_array());

	my @timeCells = (11,15,16,17,18,19,20,21);

	for my $cell (@timeCells)
		{
		for (my $row = $baseTableRows+1;$row <= $table->getTableRows();$row++)
			{
			$table->setCell($row,$cell,$formatter->($table->getCell($row,$cell)));	
			}
		}

	$table->setCell($baseTableRows+1,1,"Page");
	$table->setCell($baseTableRows+2,1,"B/F");
	$table->setCell($baseTableRows+3,1,"Total");
	$table->setCell($baseTableRows+1,24,"I certify this to be a true record");
	$table->setRowClass($baseTableRows+1,'total_row_bold');
	$table->setRowClass($baseTableRows+2,'total_row_plain');
	$table->setRowClass($baseTableRows+3,'total_row_bold');
		
	# check to see if pdf exists - if not generate it
	
	my $monthPadded = $month;
	$monthPadded = '0'.$month if ($month < 10);

	my $pdfFileName =  '/pdf/'.session('staff_id').'/Logbook_'.session('staff_id').'_'.$year.'_'.$monthPadded.'.pdf';
 
 	unless (-e config->{appdir}.config->{pubdir}.$pdfFileName) 
		{
 		my $util = Kyloe::Util::logbookToPDF->new(session('staff_id'),$month,$year);
 		$util->getPDF();
 		} 	
		
	$table->getTable();
		
	}





true;
