package Planner::UI::EditWindow;
use Gtk2;
use strict;
use warnings;
use DBI;
use Gtk2::SimpleList;
use pdf_generator;
use Planner::UI::SelectWindow;

sub new {
	my $class = shift;
	my $self = {
			job_id => shift,
			batches => [],
	};
	
	bless $self,$class;

	$self->{window} = new Gtk2::Window('toplevel');
	$self->{window}->set_title("WorkPlanner");
#	$self->{window}->signal_connect( "destroy" => sub {     Gtk2->main_quit; });
	$self->{window}->set_modal(1);
	$self->{window}->set_position('center');
	$self->{window}->set_transient_for($main::ui->{window});
	$self->{window}->set_default_size(800,600);
	$self->{window}->set_border_width(5);
	my $vbox0 = new Gtk2::VBox;
	my $hbox = new Gtk2::HBox;
	$self->{window}->add($vbox0);
	$vbox0->pack_start($hbox,1,1,0);
	
	my $vbox1 = new Gtk2::VBox;
	$hbox->pack_start($vbox1,1,1,0);
	
	$self->{list} = new Gtk2::SimpleList	(
				'Order NO' 	=> 'int',
				'Pos'		=> 'int',
				'Spec'		=> 'int',
				'Sub'		=> 'text',
				'Weight'	=> 'text',
						);
	$self->{list}->set_column_editable ($_, 1) for (0,3);
	$self->{list}->get_selection->set_mode ('multiple');
	use Data::Dumper;

	my $treeview = $self->{list};
	bless $treeview,'Gtk2::TreeView';
	
	$treeview->signal_connect('row-activated' => \&batch_activated,$self);
	
	my $scroll = new Gtk2::ScrolledWindow;
	$scroll->set_policy('automatic','automatic');
	
	$vbox1->pack_start($scroll,1,1,0);
	$scroll->add_with_viewport($self->{list});
	my $bbox = new Gtk2::HButtonBox;
	$vbox1->pack_start($bbox,0,1,0);
	$bbox->add($self->{add} =   new_from_stock Gtk2::Button('gtk-add'));
	$bbox->add($self->{remove} =  new_from_stock Gtk2::Button('gtk-remove'));
	
	$self->{add}->signal_connect('pressed' => \&Planner::UI::EditWindow::add_pressed, $self);
	$self->{remove}->signal_connect('pressed' => \&Planner::UI::EditWindow::remove_pressed, $self);
	
	
	$vbox1 = new Gtk2::VBox;
	$hbox->pack_start($vbox1,1,1,0);
	
	$vbox1->pack_start($self->{fabric} = new Gtk2::CheckButton('Fabric'),	0,1,0);
	$vbox1->pack_start($self->{have_colour} = new Gtk2::CheckButton('Colour'),	0,1,0);
	$vbox1->pack_start($self->{send_to_customer} = new Gtk2::CheckButton('Acceptation from customer'),	0,1,0);
	$vbox1->pack_start($self->{fixed} = new Gtk2::CheckButton('Fixed'),	0,1,0);
	
	$vbox1->pack_start(new Gtk2::HSeparator,0,1,0);
	
	$hbox = new Gtk2::HBox;
	$hbox->pack_start(new Gtk2::Label('Colour:'),  0,1,0);
	$hbox->pack_start($self->{colour} = new Gtk2::Entry,	1,1,0);
	$vbox1->pack_start($hbox,0,1,0);
	$vbox1->pack_start(new Gtk2::HSeparator,0,1,0);
	
	$hbox = new Gtk2::HBox;
	$hbox->pack_start(new Gtk2::Label('Recipe:'),  0,1,0);
	$hbox->pack_start($self->{recipe} = new Gtk2::Entry,	1,1,0);
	$vbox1->pack_start($hbox,0,1,0);
	$vbox1->pack_start(new Gtk2::HSeparator,0,1,0);
	
		$hbox = new Gtk2::HBox;
	$hbox->pack_start(new Gtk2::Label('Aux. weight:'),  0,1,0);
	$hbox->pack_start($self->{aux_weight} = new Gtk2::Entry,	1,1,0);
	$vbox1->pack_start($hbox,0,1,0);
	$vbox1->pack_start(new Gtk2::HSeparator,0,1,0);

#	use Data::Dumper;
#	$hbox = new Gtk2::HBox;
#	$hbox->pack_start(new Gtk2::Label('Customer:'),  0,1,0);
#	$hbox->pack_start($self->{customer} = new_text Gtk2::ComboBox,	1,1,0);
#	$vbox1->pack_start($hbox,0,1,0);
#	$vbox1->pack_start(new Gtk2::HSeparator,0,1,0);
#	$self->{customer}->append_text('SONTEX');
#	$self->{customer}->append_text('BHI');
#	$self->{customer}->append_text('n/a');
#	$self->{customer}->signal_connect(event => sub { warn Dumper(@_)});
#	
#	$hbox = new Gtk2::HBox;
#	$hbox->pack_start(new Gtk2::Label('Dess:'),  0,1,0);
#	$hbox->pack_start($self->{dess} = new Gtk2::Entry,	1,1,0);
#	$vbox1->pack_start($hbox,0,1,0);
#	$vbox1->pack_start(new Gtk2::HSeparator,0,1,0);
	
	$hbox = new Gtk2::HBox;

	$vbox0->pack_start($hbox,0,0,0);
	
	my $table = new Gtk2::Table(4,7);
	$table->set_row_spacing($_,5) for (0 .. 3);
	$table->set_col_spacing($_,8) for (0 .. 6);
	
	$hbox->pack_start($table,0,1,0);
	$table->attach(new Gtk2::Label('Duration'),0,2,0,1,[],[],0,0);
	
	$table->attach(new Gtk2::Label('Days:'),0,0+1,1,1+1,[],[],5,0); 
	$table->attach(new Gtk2::Label('Hours:'),0,0+1,2,2+1,[],[],5,0);
	$table->attach(new Gtk2::Label('Minutes:'),0,0+1,3,3+1,[],[],5,0); 
	
	$table->attach($self->{d_days} = new_with_range Gtk2::SpinButton(0,100,1)	,1,1+1,1,1+1,[],[],0,0);
	$table->attach($self->{d_hours} = new_with_range Gtk2::SpinButton(0,23,1)	,1,1+1,2,2+1,[],[],0,0);
	$table->attach($self->{d_minutes} = new_with_range Gtk2::SpinButton(0,59,1)	,1,1+1,3,3+1,[],[],0,0);
	$self->{d_hours}->set_value(12);
	
	$table->attach(new Gtk2::VSeparator,	3, 3+1, 0, 4, ['fill'],['fill'],0,0 );
	
	$table->attach(new Gtk2::Label('Starting time'),	4,5,0,0+1,['fill'],[],0,0);
	$table->attach($self->{calendar} = new Gtk2::Calendar,	4,4+1,1,4,['fill'],['fill'],0,0);
	$self->{calendar}->display_options(['show-heading','show-day-names','show-week-numbers']);

	$table->attach(new Gtk2::Label('Delivery date'),	5,6,0,0+1,['fill'],[],0,0);
	$table->attach($self->{calendar2} = new Gtk2::Calendar,	5,5+1,1,4,['fill'],['fill'],0,0);
	$self->{calendar2}->display_options(['show-heading','show-day-names','show-week-numbers']);

	$table->attach($self->{t_hour} = new_with_range Gtk2::SpinButton(0,23,1),	6,6+1,1,1+1,['fill'],[],0,0);
	$table->attach(new Gtk2::Label(':'),	7,7+1,1,1+1,['fill'],[],5,0);
	$table->attach($self->{t_minute} = new_with_range Gtk2::SpinButton(0,59,1),8,8+1,1,1+1,['fill'],[],0,0);
	$table->attach($self->{scratchpad} = new Gtk2::CheckButton('Add to scratchpad'), 5,8, 3,3+1,['fill'],[],0,0);
	$self->{scratchpad}->set_active(1);
	
	$vbox0->pack_start(new Gtk2::HSeparator,0,1,0);
	$vbox0->pack_start(new Gtk2::Label('Notes'),0,1,0);
	
	$scroll = new Gtk2::ScrolledWindow;
	$self->{comments} = new Gtk2::TextView;
	$scroll->set_policy('automatic','automatic');
	$vbox0->pack_start($scroll,1,1,0);
	$scroll->add_with_viewport($self->{comments});

	$vbox0->pack_start(new Gtk2::HSeparator,0,1,0);
	$bbox = new Gtk2::HButtonBox;
	$bbox->set_layout_default('edge');
	$vbox0->pack_start($bbox,0,0,5);
	$self->{delete} = new_from_stock Gtk2::Button('gtk-delete');
	$self->{cancel} = new_from_stock Gtk2::Button('gtk-cancel');
	$self->{apply} = new_from_stock Gtk2::Button('gtk-apply');
	$bbox->add($self->{delete});
	$bbox->add($self->{cancel});
	$bbox->add($self->{apply});
	
	$self->{calendar}->signal_connect( 'day-selected' => \&Planner::UI::EditWindow::date_selected, $self);
	$self->{t_hour}->signal_connect( 'value-changed' => \&Planner::UI::EditWindow::date_selected, $self);
	$self->{t_minute}->signal_connect( 'value-changed' => \&Planner::UI::EditWindow::date_selected, $self);

	$self->{cancel}->signal_connect('pressed' => \&Planner::UI::EditWindow::cancel_pressed, $self);
	$self->{apply}->signal_connect('pressed' => \&Planner::UI::EditWindow::apply_pressed, $self);

	if($self->{job_id}){
		$self->{delete}->signal_connect('pressed' => \&Planner::UI::EditWindow::delete_pressed, $self);
		my $q = "select fabric, have_colour, recipe, extract(epoch from end_ts-start_ts) as sec_duration, ";
		$q .=	"extract(year from start_ts), extract(month from start_ts), extract(day from start_ts), ";
		$q .=	"extract(hour from start_ts),extract(minute from start_ts), comment, id_machine,aux_weight,colour,fixed,";
		$q .=	"extract(year from delivery_date), extract(month from delivery_date), extract(day from delivery_date) from ";		
		$q .=	"xf_jobs where job_id = $self->{job_id}";
#		warn $q;
		my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
		$res->execute or warn("Database error: unable to execute query");
		while(my $row = $res->fetchrow_arrayref){
			my ($fabric,$have_colour,$recipe,$duration,$year,$month,$day,$hour,$minute,$comment, $machine_id,$aux_weight,$colour,$fixed,$syear,$smonth,$sday);
			($fabric,$have_colour,$recipe,$duration,$year,$month,$day,
				$hour,$minute, $comment, $self->{machine_id},$aux_weight,$colour,$fixed,$syear,$smonth,$sday) = @$row;
	
			$self->{calendar}->select_month($month-1,$year);
			$self->{calendar}->select_day($day);

			$self->{calendar2}->select_month($smonth-1,$syear);
			$self->{calendar2}->select_day($sday);
			
			$self->{t_hour}->set_value($hour);
			$self->{t_minute}->set_value($minute);

			$duration /= 60;
			my $d_minutes = $duration % 60;
			$duration -= $d_minutes;
			$duration /= 60;
			my $d_hours = $duration % 24;
			$duration -= $d_hours;
			$duration /= 24;
			my $d_days = $duration;
			
			$self->{d_days}->set_value($d_days);
			$self->{d_hours}->set_value($d_hours);
			$self->{d_minutes}->set_value($d_minutes);
			$self->{fabric}->set_active($fabric);
			$self->{have_colour}->set_active($have_colour);
			$self->{fixed}->set_active($fixed);
			$self->{comments}->get_buffer->set_text($comment);
			$self->{recipe}->set_text($recipe) if defined $recipe;
			$self->{colour}->set_text($colour) if defined $colour;
			$self->{aux_weight}->set_text($aux_weight) if defined $aux_weight
		}
#		$q = 	"select order_no,position,spec_no,spec_no_suffix,weight from xf_batches_in_job natural join xf_batches where job_id = $self->{job_id}";


#		warn $q;
#		$q = 	"select o.order_no, q.position,b.spec_no,b.spec_no_suffix from ".
#			"xf_batches_in_job bij, x_fproduction b, x_stock_raw s, x_order o, x_quantity q where ".
#			"bij.job_id = $self->{job_id} and bij.id_fproduction = b.id_fproduction and ".
#			"b.x_stock_id = s.stock_id and s.order_id = o.order_id and s.colour_id = q.quantity_id";
#		$res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
#		$res->execute or warn("Database error: unable to execute query");
		$main::queries{job_batches}->execute($self->{job_id});
		while(my $row = $main::queries{job_batches}->fetchrow_arrayref){
			 push @{$self->{list}->{data}},$row;
		}
		

	} else {
		$self->{machine_id} = -1;
	}
	
	$self->{window}->show_all;
	return $self;
}

sub add_pressed {
	my $self = shift;
	my $data = pop;
	
	push @{$data->{list}->{data}}, [0,0,0,'A'];
}

sub remove_pressed {
	my $self = shift;
	my $data = pop;
	
	bless $data->{list}, 'Gtk2::SimpleList';
	for (reverse $data->{list}->get_selected_indices){
		splice @{$data->{list}->{data}}, $_,1;
	}
}

sub date_selected {
	my $self = shift;
	my $data = pop;

	$data->{scratchpad}->set_active(0);
}

sub cancel_pressed {
	my $self = shift;
	my $data = pop;
	$data->{window}->destroy;
}

sub delete_pressed {
	my $self = shift;
	my $data = pop;

	my $dialog = new_with_buttons Gtk2::Dialog('Are you sure?',$data->{window},['modal','destroy-with-parent'],
			'gtk-no' => 'no', 'gtk-yes' => 'yes');
	$dialog->vbox->add(new Gtk2::Label('Are you sure you want to delete this job?'));
	$dialog->signal_connect(response=>\&Planner::UI::EditWindow::delete_response,$data);
	$dialog->show_all;
#	$dialog->run;


}

sub delete_response {
	my $dialog = shift;
	my $response = shift;
	my $data = pop;

	if($response eq 'yes'){
		$main::dbhandle->do("delete from xf_jobs where job_id = $data->{job_id}") or warn("Database error: unable to delete data");
		$data->{window}->destroy;
		if($data->{machine_id} == -1){
			$main::ui->{pad}->reload;
		} else {
			$main::ui->{machines}->{$data->{machine_id}}->reload;
		}
#		$main::ui->reload;
	}
}
	
sub apply_pressed {
	my $self = shift;
	my $data = pop;
		
	my ($y,$m,$d) = $data->{calendar}->get_date;
	my ($sy,$sm,$sd) = $data->{calendar2}->get_date;
	my ($hour,$min) = ($data->{t_hour}->get_value,$data->{t_minute}->get_value);
	my $start = "$y-".($m+1)."-$d $hour:$min";
	my $stop = "$sy-".($sm+1)."-$sd";
	
	my $duration = $data->{d_days}->get_value * 24 * 60 + $data->{d_hours}->get_value * 60 + $data->{d_minutes}->get_value;
	
	my $b = $data->{comments}->get_buffer;
	my $comments = $b->get_text($b->get_bounds,1);
	my $have_colour = $data->{have_colour}->get_active?'t':'f';
	my $fabric = $data->{fabric}->get_active?'t':'f';
	my $fixed = $data->{fixed}->get_active?'t':'f';
	my $send_to_customer = $data->{send_to_customer}->get_active?'t':'f';
	my $recipe = $data->{recipe}->get_text;
	my $colour = $data->{colour}->get_text;
#	warn "Recipe: $recipe, Colour: $colour";
	my $aux_weight_raw = $data->{aux_weight}->get_text;
	$aux_weight_raw =~ y/,/./;
	my @arr = split /\s*([-+])\s*/, $aux_weight_raw;
	my $t = shift @arr;
	my $aux_weight = 0;
	if (defined $t){
		($aux_weight) = ($t =~ /(\d*(\.\d*)?)/);
		while($#arr > 0){
			my ($s,$v) = (shift @arr,shift @arr);
			$aux_weight += $v if $s eq '+';
			$aux_weight -= $v if $s eq '-';

		}
		$aux_weight =~ y/,/./;
	} else {
		$aux_weight = 0;
	}
	my $mtr;
	$mtr = $data->{machine_id},$data->{machine_id} = -1 if $data->{scratchpad}->get_active;
	if($data->{machine_id} != -1 and int($main::opts{ABIDE_OVERLAP})){
		
		my $q = "select count(*) from xf_jobs where (timestamptz '$start', timestamptz '$start' + interval '$duration minutes') ".
			"overlaps (start_ts,end_ts) and id_machine = $data->{machine_id}";
		$q .= " and job_id <> $data->{job_id}" if defined $data->{job_id};

		my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
		$res->execute or warn("Database error: unable to execute query");
		my $c;
		while(my $row = $res->fetchrow_arrayref){
			$c = $$row[0];
		}
		if($c != 0){
	                my $dialog = new Gtk2::MessageDialog($data->{window},['destroy-with-parent', 'modal'],'error','ok',
				'The job positioned here would overlap another job. I can\'t allow that.');
			$dialog->signal_connect (response => sub { $_[0]->destroy });
			$dialog->show_all;
			return;
		}
	}
	my $insert = 0;
	if(defined $data->{job_id}){
		warn $stop;
		$main::dbhandle->do("delete from xf_batches_in_job where job_id = $data->{job_id}") or warn("Database error: unable to delete data");
		my $q = "update xf_jobs set start_ts=timestamptz '$start',end_ts = timestamp '$start' + interval '$duration minutes', ".
			"comment='$comments',have_colour='$have_colour',fabric='$fabric',recipe='$recipe', delivery_date = ('$stop')::date ,id_machine = $data->{machine_id},aux_weight=$aux_weight,colour='$colour',fixed='$fixed' ".
			"where job_id = $data->{job_id}";
		$main::dbhandle->do($q) or warn("Database error: unable to update data");
	} else {
#		warn "!";
		$insert = 1;
		my $q = "insert into xf_jobs values (default,default,timestamptz '$start',timestamp '$start' + interval '$duration minutes', ".
			"'$comments','$fabric','$have_colour','$recipe',$aux_weight,'$colour'); select currval('xf_jobs_job_id_seq');";
#		warn $q;
		
		my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
		$res->execute or warn("Database error: unable to execute query");
		my $row = $res->fetchrow_arrayref;
		$data->{job_id} = $$row[0];
#		warn "?";
	}

	my @data = @{$data->{list}->{data}};
	while(my $row = shift @data){
#		warn Dumper($row);
		my $q = "insert into xf_batches_in_job values (default,$data->{job_id},".int($$row[0])."," .
			int($$row[1]).",".int($$row[2]).", upper('$$row[3]'))";
#		warn $q;
		$main::dbhandle->do($q) or warn("Database error: unable to insert data");
	}
	$data->{window}->destroy;
	$main::ui->{pad}->reload;
	if (!$insert ){
		$main::ui->{machines}->{$data->{machine_id}}->reload;
#		$main::ui->reload;
	}
	$main::ui->{machines}->{$mtr}->reload if defined $mtr;
}

sub new_pressed {
	die('Unimplemented'); #TODO
}

sub batch_activated {
	my $self = pop;
	my $title = $_[2]->get_title;
	if($title eq 'Pos'){
		my $selwin = new_position Planner::UI::SelectWindow(@_,$self);
	} elsif($title eq 'Spec'){
		my $selwin = new_spec Planner::UI::SelectWindow(@_,$self);

	}
}

1;
