package Planner::UI::TimeAdjustment;
use Gtk2;
use strict;
use warnings;
use DBI;


sub new {
	my $class = shift;
	my $self = 	{
				job_id => shift,	
			};
	bless $self,$class;
	my $vbox = new Gtk2::VBox;
	$vbox->set_border_width(5);

	$self->{window} = new Gtk2::Window('toplevel');
	$self->{window}->set_title("WorkPlanner");
#	$self->{window}->signal_connect( "destroy" => sub {     Gtk2->main_quit; });
	$self->{window}->set_modal(1);
	$self->{window}->set_position('mouse');
	$self->{window}->set_transient_for($main::ui->{window});
#	$self->{window}->set_default_size(160,100);
#	$self->{window}->signal_connect( "destroy" => sub {     Gtk2->main_quit; });
	
	my $table = new Gtk2::Table(2,2,1);
	$table->attach(new Gtk2::Label('Hours:'), 	0,1,0,1, ['expand'],[],0,0);
	$table->attach(new Gtk2::Label('Minutes:'), 	0,1,1,2, ['expand'],[],0,0);
#	$table->attach(new Gtk2::Label('Spec Suffix'),  3,4,0,1, ['expand'],[],0,0);
	
	$table->attach($self->{hours} 	= new_with_range Gtk2::SpinButton(-20,20,1), 1,2,0,1, ['expand'],[],5,0);
	$table->attach($self->{minutes}	= new_with_range Gtk2::SpinButton(-60,60,1), 1,2,1,2, ['expand'],[],5,0);
	
	$self->{hours}->set_value(0);
	$self->{minutes}->set_value(0);
	my$bbox = new Gtk2::HButtonBox;
	$bbox->set_layout_default('edge');
	
	$bbox->add($self->{cancel} = new_from_stock Gtk2::Button('gtk-cancel'));
	$bbox->add($self->{apply} = new_from_stock Gtk2::Button('gtk-apply'));
#        $table->attach($bbox, 0,1,2,3, ['fill','expand'],['fill'],0,0);


	$self->{cancel}->signal_connect(pressed => \&cancel_pressed,$self);
	$self->{apply}->signal_connect(pressed => \&apply_pressed,$self);

	$vbox->pack_start($table,0,1,0);
	$vbox->pack_start(new Gtk2::HSeparator,0,1,0);
	$vbox->pack_start($bbox,1,1,0);
	
	$self->{window}->add($vbox);
		
	$self->{window}->show_all;
	
	return $self;
}

sub cancel_pressed {
	my $win = pop;
	$win->{window}->destroy;
}

sub apply_pressed {
	my $win = pop;
	
	my $m = $win->{hours}->get_value*60 + $win->{minutes}->get_value;
	
	my $q =	"update xf_jobs set start_ts=start_ts + interval '$m minutes',end_ts=end_ts + interval '$m minutes' where ".
		"job_id in (select j.job_id from xf_jobs j join xf_jobs r on (r.id_machine = j.id_machine) where ".
		"j.start_ts >= r.start_ts and r.job_id = $win->{job_id})";
	$main::dbhandle->do($q) or warn("Database error: unable to update data");
	$win->{window}->destroy;
	$main::ui->reload;
}

1;
