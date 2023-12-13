package Planner::UI;
use warnings;
use strict;
use Gtk2;
use Planner::UI::Machine;
use Planner::UI::Timeline;
use Planner::UI::Pad;
use Planner::UI::EditWindow;
use Planner::UI::FindWindow;
use Planner::UI::TimeAdjustment;
#use Planner::UI::PrintWindow;
use DBI;
use Gtk2::SimpleList;
use pdf_generator;
use Gtk2::Gdk::Keysyms;

our $shadow;# = new Gtk2::ProgressBar;	
#$shadow->modify_bg('normal',new Gtk2::Gdk::Color(60000,60000,60000));
our $tooltip; 

our $threshold = 0;
our %widgets;

our %days = ('3 days' => 3, '7 days' => 7,'14 days' => 14,'30 days' => 30);
our @days_order = ('3 days','7 days','14 days','30 days');
our %zoom = ('100%' => 1, '50%' => 0.5,'25%' => 0.25,'20%' => 0.2, '15%'=>0.15,'10%' => 0.1, '5%' => 0.05, '1%' => 0.01);
our @zoom_order = ('100%','50%','25%','20%','15%','10%','5%','1%');
our $last_days;

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;

	$last_days = $main::opts{NUM_DAYS};
	$self->{dbhandle} = shift;
	$self->{machines} = {};
 $self->{window} = new Gtk2::Window("toplevel");
$self->{window}->set_title("WorkPlanner");
$self->{window}->set_default_size(1024,768);
$self->{window}->signal_connect( "destroy" => sub {	Gtk2->main_quit; });
$self->{window}->set_position('center');

my $box = new Gtk2::VBox(0,0);
$self->{window}->add($box);

my $hpaned = new Gtk2::HPaned;
$hpaned->set_position(240);

$box->pack_start($hpaned,1,1,0);


my $left_scrolled_window = new Gtk2::ScrolledWindow;
my $right_scrolled_window = new Gtk2::ScrolledWindow;

$left_scrolled_window->set_policy('automatic','automatic');
$right_scrolled_window->set_policy('never','automatic');


$hpaned->add1($left_scrolled_window);
$hpaned->add2($right_scrolled_window);

$box = new Gtk2::VBox(0,0);

my $hbox = new Gtk2::HBox;
$hbox->pack_start($self->{reload_indicator} = new Gtk2::ProgressBar,1,1,0);
$hbox->pack_start($self->{reload} = new_from_stock Gtk2::Button('gtk-refresh'),0,0,0);
#$self->{reload_indicator}->set_pulse_step(0.1);
$box->pack_start($hbox,0,0,0);


$box->pack_start(new Gtk2::HSeparator,0,1,0);

$hbox = new Gtk2::HBox;
$hbox->pack_start($self->{days} = new_text Gtk2::ComboBox,1,1,0);
$hbox->pack_start($self->{zoom} = new_text Gtk2::ComboBox,1,1,0);
$hbox->pack_start($self->{zoom_apply} = new_from_stock Gtk2::Button('gtk-apply'),1,1,0);
$self->{zoom_apply}->signal_connect(pressed => \&zoom_apply_pressed, $self);
$box->pack_start($hbox,0,0,0);



$self->{days}->append_text($_) for (@days_order);
$self->{zoom}->append_text($_) for (@zoom_order);
$self->{days}->set_active(0);
$self->{zoom}->set_active(0);


$box->pack_start(new Gtk2::HSeparator,0,1,0);
$self->{calendar} = new Gtk2::Calendar;

$left_scrolled_window->add_with_viewport($box);

$self->{calendar}->display_options(['show-heading','show-day-names','show-week-numbers']);

$box->pack_start($self->{calendar},0,1,0);

$box->pack_start(new Gtk2::HSeparator,0,1,0);
$box->pack_start($self->{print} = new_from_stock Gtk2::Button('gtk-print'),0,1,0);
$box->pack_start(new Gtk2::HSeparator,0,1,0);
$box->pack_start($self->{find_job} = new_from_stock Gtk2::Button('gtk-find'),0,1,0);


$box->pack_start(new Gtk2::HSeparator,0,1,0);

$self->{new_job} = new_from_stock Gtk2::Button('gtk-new');

if($main::opts{NEW_JOBS}){
	$box->pack_start($self->{new_job},0,1,0);
	$box->pack_start(new Gtk2::HSeparator,0,1,0);
}


$self->{pad} = new Planner::UI::Pad($box);
#$self->{pad}->reload;



$hbox = new Gtk2::HBox(0,0);
my ($vbox1,$vbox2) = (new Gtk2::VBox(0,0), new Gtk2::VBox(0,0));
$vbox1->set_border_width(2);
$vbox2->set_size_request($main::opts{ROW_WIDTH},-1);

$right_scrolled_window->add_with_viewport($hbox);
$hbox->pack_start($vbox1,0,0,0);
$hbox->pack_start(new Gtk2::VSeparator,0,1,0);

$self->{time_grid} = new Gtk2::ScrolledWindow;
$hbox->pack_start( $self->{time_grid},1,1,0);
$self->{time_grid}->set_policy('always','never');
$self->{time_grid}->add_with_viewport($vbox2);
	$self->{vbox1} = $vbox1;
	$self->{vbox2} = $vbox2;
	

	my ($year,$month,$day) = $self->{calendar}->get_date;
	$self->{date} = $year.'-'.($month+1)."-$day";
	$self->reload_all;
#	$self->reload;
	
$self->{window}->signal_connect('drag-motion',\&Planner::UI::fixed_drag_motion_handler);	
$self->{new_job}->signal_connect('pressed',\&Planner::UI::new_job);	
$self->{find_job}->signal_connect('pressed',\&Planner::UI::find_job);	
	

	$self->{window}->signal_connect (key_press_event => sub {
			my ($widget, $event) = @_;
			return  unless $event->keyval == $Gtk2::Gdk::Keysyms{Escape};
			Gtk2->main_quit;
			return 1;
	});
	
	$self->{timeout} = Glib::Timeout->add($main::opts{REFRESH_DELAY}/100, \&timeout_handler, $self);
	$self->{calendar}->signal_connect('day-selected',\&Planner::UI::calendar_day_selected_handler,$self);
	$self->{reload}->signal_connect(clicked => \&refresh_pressed, $self);
	$self->{print}->signal_connect(clicked => \&print_pressed );

	return $self;
}

sub timeout_handler {
	my $self = shift;

my $f = $self->{reload_indicator}->get_fraction;
	if($f >= 0.98){
		$self->{reload_indicator}->set_text('Reloading...');
		if($f >= .99){
			$self->reload;
			$self->{reload_indicator}->set_text('');
			$self->{reload_indicator}->set_fraction(0.0);
		}else{ $self->{reload_indicator}->set_fraction($f+0.01); }
	} else {
		$self->{reload_indicator}->set_fraction($f+0.01);
	}
	return 1;
}

sub refresh_pressed {
	my $self = pop;
	Glib::Source->remove($self->{timeout});
	$self->{reload_indicator}->set_text('Reloading...');
	$self->{reload_indicator}->set_fraction(1.0);
	$self->reload;
	$self->{reload_indicator}->set_text('');
	$self->{reload_indicator}->set_fraction(0.0);
	$self->{timeout} = Glib::Timeout->add($main::opts{REFRESH_DELAY}/100, \&timeout_handler, $self);
}

sub print_pressed {
	my $self = pop;
	pdf_generator::get_plan_pdf();
}

sub zoom_apply_pressed {
	my $self = pop;
	my $old = $main::opts{ROW_WIDTH};	
	$main::opts{NUM_DAYS} = $days{$days_order[$self->{days}->get_active]};
	$main::opts{PIXELS_PER_MINUTE} = $main::defaults{PIXELS_PER_MINUTE} * $zoom{$zoom_order[$self->{zoom}->get_active]};
	$main::opts{PIXELS_PER_HOUR} = 60*$main::opts{PIXELS_PER_MINUTE};
	$main::opts{PIXELS_PER_DAY} = 24*$main::opts{PIXELS_PER_HOUR};
	$main::opts{ROW_WIDTH} = 24 * $main::opts{PIXELS_PER_HOUR} * $main::opts{NUM_DAYS};
	$main::opts{SKIP_HOURS} = 24;
	$old /= $main::opts{ROW_WIDTH};
	$self->{vbox2}->set_size_request($main::opts{ROW_WIDTH},-1);
	
	my $q = "select extract(epoch from now() - '$self->{date}'::timestamptz)";
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	while(my $row = $res->fetchrow_arrayref){
		$threshold = ($$row[0]*$main::opts{PIXELS_PER_MINUTE})/60;
	}
	if($days{$days_order[$self->{days}->get_active]} == $last_days){
		for(values %{$self->{machines}}){
			$_->scale($old);
		}
	} else {
		$last_days = $days{$days_order[$self->{days}->get_active]};
		Glib::Source->remove($self->{timeout});
		$self->{reload_indicator}->set_text('Reloading...');
		$self->{reload_indicator}->set_fraction(1.0);
		$self->reload;
		$self->{reload_indicator}->set_text('');
		$self->{reload_indicator}->set_fraction(0.0);
		$self->{timeout} = Glib::Timeout->add($main::opts{REFRESH_DELAY}/100, \&timeout_handler, $self);
	}
	
}

sub reload_all {
	my $self = shift;
	$threshold = 0;
	my $q = "select id_machine,machine_number,yarn,capacity_from_to from xf_machines where id_machine <> -1 order by machine_number";
#	warn $q;
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	$self->{timeline} = new Planner::UI::Timeline($self->{vbox1},$self->{vbox2},$self->{time_grid});
	$self->{machines} = {};
	my $row =  $res->fetchall_arrayref;
	for (my $i = 0; $i <= $#{$row}; $i++) {
		$self->{machines}->{$row->[$i]->[0]} = new Planner::UI::Machine($row->[$i]->[0],$row->[$i]->[1],$self->{date},$self->{vbox1},$self->{vbox2});
		$self->{machines}->{$row->[$i]->[0]}->reload;
		}
		if($res->err) { warn("Database error: error while fetching result");};
		#$self->{pad}->reload;
		$self->{machines}->{-1} = $self->{pad};
}

sub reload {

	my $self = shift;
	my $q = "select extract(epoch from now() - '$self->{date}'::timestamptz)";
#	warn $q;
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	while(my $row = $res->fetchrow_arrayref){
		$threshold = ($$row[0]*$main::opts{PIXELS_PER_MINUTE})/60;
	}

	for(values %{$self->{machines}}){
		$_->reload($self->{date});
	}
	$self->{pad}->reload;

1;
}


sub dumper {
#	warn Dumper(@_);
#	warn Dumper($_[0]->get_selected_indices);
#	awarn Dumper(pop);
#	warn $_->type;
	0;
}

sub edit_job {
	my $job_id = pop;
	my $ew = new Planner::UI::EditWindow($job_id);
}
sub adjust_job {
	my $job_id = pop;
	my $ew = new Planner::UI::TimeAdjustment($job_id);
}
sub new_job {
	my $ew = new Planner::UI::EditWindow;
}
sub find_job {
	my $fw = new Planner::UI::FindWindow;
}

sub bar_button_press_handler {
#	warn Dumper(@_);
	my ($widget,$event) = @_;
#	warn Dumper($event);
#	warn $event->type.' - '.$event->button;
	
	if($event->button == 3){
		my $menu = new Gtk2::Menu;

		my $item1 = new Gtk2::MenuItem("Print order");
		my $sub = new Gtk2::Menu;
		
		for(keys %{$widget->{orders}}){
			my $temp = new Gtk2::MenuItem("ON: $_");
			$temp->signal_connect(activate => \&pdf_generator::get_order_pdf, $widget->{orders}->{$_});
			$sub->append($temp);
		}
		$item1->set_submenu($sub);
		
		my $item2 = new Gtk2::MenuItem("Print details");
		$sub = new Gtk2::Menu;
		for(keys %{$widget->{orders}}){
			my $temp = new Gtk2::MenuItem("ON: $_");
			$temp->signal_connect(activate => \&pdf_generator::get_job_detail_pdf, $widget->{orders}->{$_});
			$sub->append($temp);
		}
		$item2->set_submenu($sub);
		
		my $item3 = new Gtk2::MenuItem("Edit job");
		$item3->signal_connect(activate => \&Planner::UI::edit_job, $widget->{job_id});
		my $item4 = new Gtk2::MenuItem("Adjust jobs");
		$item4->signal_connect(activate => \&Planner::UI::adjust_job, $widget->{job_id});
	
		$menu->append($item1) if $main::opts{MENU_ORDER};
		$menu->append($item2) if $main::opts{MENU_DETAILS};
		$menu->append($item3) if $main::opts{MENU_EDIT};
		$menu->append($item4) if $main::opts{MENU_ADJUST};
	
	#	$item0->signal_connect(activate => sub { warn Dumper(@_); $_[1]->popdown; $_[1]->destroy; },$menu);
	#	$item0->signal_connect(activate_item => sub { warn Dumper(@_); $_[1]->popdown; $_[1]->destroy; },$menu);
		
	#	$menu->append($item0);
		$menu->show_all;
		$menu->popup(undef,undef,undef,undef,$event->button,$event->time);
	}
	0;
}

sub label_drop {
	my ($dest,$context,$new_x,$new_y,$int,$data) = @_;
	my $src = $context->get_source_widget;
	$shadow->hide;
#FIXME: napisac reszte
}

sub bar_drag_begin_handler {
#	warn "Drag begin: ".Dumper(@_);
	my $src_widget = shift;
	my $allocation = $src_widget->allocation;
	my $parent = $src_widget->parent;
	$shadow = new Gtk2::ProgressBar;
	$shadow->set_size_request(($main::opts{PIXELS_PER_MINUTE}*$src_widget->{sec_duration})/60,$allocation->height);#  $allocation);
	$shadow->modify_bg('normal',new Gtk2::Gdk::Color(30000,30000,30000));
#	warn Dumper($src_widget->parent);
	$shadow->unparent;
	$shadow->set_text($src_widget->get_text);
	$parent->put($shadow,$allocation->x,$allocation->y);
	$shadow->show;
	$src_widget->hide;
}


sub bar_drag_drop_handler {
#	warn "Drag drop: ".Dumper(@_);	
#       
	my $q;
	my ($dest_widget, $drag_context, $x, $y) = @_;
	my $src_widget = $drag_context->get_source_widget;
	$shadow->destroy;
	if( $main::opts{ABIDE_TIME} and $x < $threshold){
		$src_widget->show;
		my $dialog = new Gtk2::MessageDialog($main::ui->{window},['destroy-with-parent', 'modal'],'error','ok','Positioning a job here would mean going back in time. I can\'t allow that.');
		$dialog->signal_connect (response => sub { $_[0]->destroy });
		$dialog->show_all;
		return;
	}
	my $offset = int($x/$main::opts{PIXELS_PER_MINUTE});
		
	if( $main::opts{ABIDE_OVERLAP}){	
		my $q =	"select count(*) from xf_jobs where id_machine = $dest_widget->{machine_id} and job_id <> $src_widget->{job_id} and".
			"(date '$main::ui->{date}' + interval '$offset minutes',  date '$main::ui->{date}' + interval '$offset minutes' + ".
			"interval '$src_widget->{sec_duration} seconds') overlaps (start_ts,end_ts)";
		my $c;
#		warn $q;
		my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
		$res->execute or warn("Database error: unable to execute query");
		while(my $row = $res->fetchrow_arrayref){
#			warn @$row;
			$c = $$row[0];
		}
		
		if($c != 0){
			my $d = new Gtk2::MessageDialog($main::ui->{window},['destroy-with-parent', 'modal'],'error','ok','The job positioned here would overlap another job. I can\'t allow that.');
			$d->signal_connect (response => sub { $_[0]->destroy });
			$d->show_all;
			$src_widget->show;
			return;
		}
	}
	
	$q = "update xf_jobs set start_ts=date '$main::ui->{date}' + interval '$offset minutes',".
		"end_ts=date '$main::ui->{date}' + interval '$offset minutes' + interval '$src_widget->{sec_duration} seconds',".
		"id_machine=$dest_widget->{machine_id}  where job_id=$src_widget->{job_id}";
#	warn $q;
	$main::dbhandle->do($q) or warn("Database error: unable to execute query");
	if($dest_widget->{machine_id} != $src_widget->{machine_id}){
		$main::ui->{machines}->{$src_widget->{machine_id}}->reload;
	}
	$main::ui->{machines}->{$dest_widget->{machine_id}}->reload;

	
	
	
	
##	warn Dumper($src_widget);
}

sub bar_drag_end_handler {
	my $src_widget = shift;
	$src_widget->show;
	$shadow->destroy;
}



sub fixed_drag_motion_handler {
	my ($widget,undef,$x,$y) = @_;
	$shadow->reparent($widget) if($widget != $shadow->parent);
#	$Planner::UI::shadow->unparent;
	$y -= $y % ($main::opts{ROW_HEIGHT} + 2);
	if(defined $widget->{ispad}){
		$widget->move($Planner::UI::shadow,0,$y);
	} else {
		if($x >= $threshold or $main::opts{ABIDE_TIME} == 0){
			$widget->move($Planner::UI::shadow,$x,$y);
		}
	}
	
}

sub calendar_day_selected_handler {
#	warn Dumper(@_);
	my ($cal,$ui) = @_;
	my ($year,$month,$day) = $cal->get_date;
	$ui->{date} = $year.'-'.($month+1)."-$day";
	$ui->reload;
	my $adj = $ui->{time_grid}->get_hadjustment;
	my $q = "select extract(epoch from now() - date '$ui->{date}')";
#	warn $q; 
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	while(my $row = $res->fetchrow_arrayref){
		my $o = ($$row[0] * $main::opts{PIXELS_PER_MINUTE})/60;
		$adj->value($o);
	}
	$ui->{time_grid}->set_hadjustment($adj);
	$ui->{timeline}->make_me_invalid;


}

sub pad_drag_drop_handler {
	my $dest_widget = shift;
	my $drag_context = shift;
	my $src_widget = $drag_context->get_source_widget;
	$shadow->destroy;

	my $q = "update xf_jobs set id_machine=-1 where job_id=$src_widget->{job_id}";
#	warn $q;
	$main::dbhandle->do($q) or warn("Database error: unable to execute query");
#	$main::ui->{pad}->reload;
	if($dest_widget->{machine_id} != $src_widget->{machine_id}){
		$main::ui->{machines}->{$src_widget->{machine_id}}->reload;
	}
	$main::ui->{pad}->reload;
}

sub bar_mouse_in {
	my ($widget,$event) = @_;
	return if defined $Planner::UI::tooltip;
	$Planner::UI::tooltip = new Gtk2::Window('popup');
	$Planner::UI::tooltip->set_decorated(0);
	$Planner::UI::tooltip->set_gravity('static');
	$Planner::UI::tooltip->modify_bg ('normal', new Gtk2::Gdk::Color(60000,60000,40000)); # The obligatory yellow
	my $text = "JobID: $widget->{job_id}\n\n";
	for(@{$widget->{batches}}){
		$text .= "$_\n";
	}
	$text .= 'Sum: '.$widget->{sum_weight}." kg\n\n";
	$text .= $widget->{comment} if defined $widget->{comment};
	$Planner::UI::tooltip->add(new Gtk2::Label($text));
#a	$tooltip->set_position(
	$Planner::UI::tooltip->set_position('mouse');;
	my($x,$y) = $Planner::UI::tooltip->get_position;
	my($w,$h) = $Planner::UI::tooltip->get_size;
	$Planner::UI::tooltip->move($x+$w/2+10,$y+$h/2+10);
		
	$Planner::UI::tooltip->show_all;



}
sub bar_mouse_out {
	return unless defined $Planner::UI::tooltip;
	$Planner::UI::tooltip->hide_all;
	$Planner::UI::tooltip->destroy;
	$Planner::UI::tooltip = undef;
}
1;
