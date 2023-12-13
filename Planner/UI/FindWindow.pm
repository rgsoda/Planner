package Planner::UI::FindWindow;
use Gtk2;
use strict;
use warnings;
use DBI;
use Gtk2::SimpleList;
use Gtk2::Gdk::Keysyms;

sub new {
	my $class = shift;
	my $self = 	{
				
			};
	bless $self,$class;

	$self->{window} = new Gtk2::Window('toplevel');
	$self->{window}->set_title("WorkPlanner");
#	$self->{window}->signal_connect( "destroy" => sub {     Gtk2->main_quit; });
	$self->{window}->set_modal(1);
	$self->{window}->set_position('center');
	$self->{window}->set_transient_for($main::ui->{window});
	$self->{window}->set_default_size(320,400);
#	$self->{window}->signal_connect( "destroy" => sub {     Gtk2->main_quit; });
	
	my $vbox = new Gtk2::VBox;
	$self->{window}->add($vbox);
	
	my $table = new Gtk2::Table(5,3,1);
	$table->attach(new Gtk2::Label('Order NO'), 	0,1,0,1, ['expand'],[],0,0);
	$table->attach(new Gtk2::Label('Position'), 	1,2,0,1, ['expand'],[],0,0);
	$table->attach(new Gtk2::Label('Spec NO'),  	2,3,0,1, ['expand'],[],0,0);
#	$table->attach(new Gtk2::Label('Spec Suffix'),  3,4,0,1, ['expand'],[],0,0);
	
	$table->attach($self->{order} = new Gtk2::Entry, 0,1,1,2, ['expand'],[],5,0);
	$table->attach($self->{pos}   = new Gtk2::Entry, 1,2,1,2, ['expand'],[],5,0);
	$table->attach($self->{batch} = new Gtk2::Entry, 2,3,1,2, ['expand'],[],5,0);
#	$table->attach($self->{suffix}= new Gtk2::Entry, 3,4,1,2, ['expand'],[],5,0);
	

	$table->attach(new Gtk2::Label('Colour'), 	0,1,2,3, ['expand'],[],0,0);
	$table->attach($self->{colour} = new Gtk2::Entry, 0,1,3,4, ['expand'],[],5,0);
	$table->attach(new Gtk2::Label('Recipe'), 	1,2,2,3, ['expand'],[],0,0);
	$table->attach($self->{recipe} = new Gtk2::Entry, 1,2,3,4, ['expand'],[],5,0);

	$table->attach($self->{find}= new_from_stock Gtk2::Button('gtk-find'), 2,3,2,4, ['expand','fill'],['expand','fill'],5,5);
	
	$table->attach($self->{filter_colour} = new Gtk2::CheckButton('No colour'), 0,1,4,5,['expand'],[],0,0); 
	$table->attach($self->{filter_recipe} = new Gtk2::CheckButton('No recipe'), 1,2,4,5,['expand'],[],0,0); 
	$table->attach($self->{filter_accepted} = new Gtk2::CheckButton('Unaccepted'), 2,3,4,5,['expand'],[],0,0); 
	
	$self->{find}->signal_connect('pressed' => \&Planner::UI::FindWindow::find_pressed, $self);
	$self->{order}->signal_connect('activate' => \&Planner::UI::FindWindow::find_pressed, $self);
	$self->{pos}->signal_connect('activate' => \&Planner::UI::FindWindow::find_pressed, $self);
	$self->{batch}->signal_connect('activate' => \&Planner::UI::FindWindow::find_pressed, $self);
	$self->{recipe}->signal_connect('activate' => \&Planner::UI::FindWindow::find_pressed, $self);
	$self->{colour}->signal_connect('activate' => \&Planner::UI::FindWindow::find_pressed, $self);
	
	$vbox->pack_start($table,0,0,5);
#	$vbox->pack_start(new Gtk2::HSeparator, 0,1,0);
	
	$self->{list} = new Gtk2::SimpleList	(
				'Job ID'	=> 'int',
				'Order NO' 	=> 'int',
				'Pos'		=> 'int',
				'Spec'		=> 'int',
				'Sub'		=> 'text',
				'Weight'	=> 'text',
				'Machine'	=> 'text',
				'Colour'	=> 'text',
				'Recipe'	=> 'text',
				'Dess'		=> 'text',
				'Starting at'	=> 'text',
				
						);
	
	$self->{list}->get_column($_)->set_sort_column_id($_) for (0 .. 10);
	$self->{list}->set_enable_search(0);
		
	$self->{list}->signal_connect(row_activated => \&Planner::UI::FindWindow::row_activate, $self);
	
	my $sc = new Gtk2::ScrolledWindow;
	$sc->set_policy('automatic','automatic');
	$sc->add_with_viewport($self->{list});
	
	$vbox->pack_start($sc,1,1,5);
	
	if($main::opts{FIND_PRINT}){
		$self->{list}->get_selection->set_mode ('multiple');
		$vbox->pack_start($self->{print} = new_from_stock Gtk2::Button('gtk-print'),0,0,0);
		$self->{print}->signal_connect( clicked => sub{
			my @post;
			my @sel = $self->{list}->get_selected_indices;
			for(@sel){ push @post, ${$self->{list}->{data}->[$_]}[0]; }
			pdf_generator::job_find_report(@post);
		});
	}
	$self->{window}->show_all;
#	push @{$self->{list}->{data}}, (1,2,3,4,'a','b','c','d');
#	@{$self->{list}->{data}} = (
#					[1,2,3,4,'a','b','c','d'],
#					[2,2,3,4,'a','b','c','d'],
#				);
	
	
	$self->{window}->signal_connect (key_press_event => sub {
		my ($widget, $event) = @_;
		return  unless $event->keyval == $Gtk2::Gdk::Keysyms{Escape};
		$self->{window}->destroy;
		return 1;
	});


	
	return $self;
}

sub find_pressed {
	my $self = pop;
	@{$self->{list}->{data}} = ();
	my $q = "select job_id,b.order_no,position,spec_no,spec_no_suffix,coalesce(weight,0)+coalesce(aux_weight,0),id_machine,colour,recipe, ".
		"coalesce(q.customer_quality_no, q.quality_no, q.quality_dk_no), to_char(start_ts,\'YYYY-MM-DD HH24:MI\') ".
		"from (xf_batches_in_job natural left join xf_batches natural join xf_jobs) b left join  ".
		"(x_order join x_quality on (x_order.quality = x_quality.quality_id)) q on (q.order_no = b.order_no)where true";
	$q .= " and b.order_no = ".int($self->{order}->get_text) if $self->{order}->get_text;
	$q .= " and b.position = ".int($self->{pos}->get_text) if $self->{pos}->get_text;
	$q .= " and b.spec_no = ".int($self->{batch}->get_text) if $self->{batch}->get_text;
	$q .= " and b.colour ilike '%".$self->{colour}->get_text."%'" if $self->{colour}->get_text;
	$q .= " and b.recipe ilike '%".$self->{recipe}->get_text."%'" if $self->{recipe}->get_text;
	$q .= " and coalesce(b.colour,'') = ''" if $self->{filter_colour}->get_active;
	$q .= " and coalesce(b.recipe,'') = ''" if $self->{filter_recipe}->get_active;
	$q .= " and not have_colour " if $self->{filter_accepted}->get_active;
	$q .= " order by start_ts";
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	while(my $row = $res->fetchrow_arrayref){
		$$row[6] = 'scratchpad' if  $$row[6] == -1;
		push @{$self->{list}->{data}}, $row;
	}

}

sub row_activate {
	my $list = shift;
	my $window = pop;
	my $ui = $main::ui;
	my @sel = $list->get_selected_indices; 
	my $i = pop @sel; 
	
	my ($job_id,$machine,$start) = ($list->{data}[$i][0],$list->{data}[$i][6],$list->{data}[$i][10]);
	my ($y,$m,$d,$h,$min) = ($start =~ /^(\d+)-(\d+)-(\d+) (\d+):(\d+)/);
#	warn Dumper($start,$y,$m,$d);
	$ui->{calendar}->select_month($m-1,$y);
	$ui->{calendar}->select_day($d);
	
	my $adj = $ui->{time_grid}->get_hadjustment;
	
	my $o = ($h * 60 + $min) * $main::opts{PIXELS_PER_MINUTE};
	$adj->value($o);
	$ui->{time_grid}->set_hadjustment($adj);

	$Planner::UI::widgets{$job_id}->modify_bg('normal'  ,$main::opts{BAR_HIGHLIGHT_BG});
	$Planner::UI::widgets{$job_id}->modify_bg('prelight',$main::opts{BAR_HIGHLIGHT_FG});
								
	
#	$window->{window}->destroy;
}

1;
