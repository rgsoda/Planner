package Planner::UI::Machine;
use strict;
use warnings;
use Gtk2;


sub new {
	my $class = shift;
	
	die "no \$dbhandle declared in main" unless defined $main::dbhandle;
	my $self = 	{ 
				machine_id => shift,
				label => new Gtk2::Label(shift),
				date => shift,
				label_parent => shift, 
				bar_parent => shift,
				jobs => [],
				bs => new Gtk2::Fixed,		# bar space
			};
		
	bless $self,$class;
	$self->{label}->set_size_request(-1, $main::opts{ROW_HEIGHT});
	$self->{label}->set_alignment(0.5, 0.5);
	$self->{label_parent}->pack_start( $self->{label},0,0,0);
	$self->{label_parent}->pack_start( new Gtk2::HSeparator,0,1,0);
	
	
	$self->{bs}->set_size_request(-1, $main::opts{ROW_HEIGHT});
	
	$self->{bar_parent}->pack_start( $self->{bs},0,1,0);
	$self->{bar_parent}->pack_start( new Gtk2::HSeparator,0,1,0);
	
	$self->{label}->drag_dest_set ('all', ['move'], {'target' => "grid", 'flags' => 'same-app', 'info' => 0});
	$self->{bs}->drag_dest_set ('all', ['move'], {'target' => "grid", 'flags' => 'same-app', 'info' => 0});
	$self->{bs}->signal_connect('drag-motion',\&Planner::UI::fixed_drag_motion_handler);
	$self->{bs}->signal_connect('drag-drop',\&Planner::UI::bar_drag_drop_handler);
	$self->{bs}->{machine_id} = $self->{machine_id};
	
	return $self;
}

sub reload {
	my $self = shift;
	if(@_){ $self->{date} = shift; }
	
	my $date =  $self->{date};
	my $q = 
	"select job_id, start_ts, end_ts, comment, fabric,have_colour, extract(epoch from start_ts - '$date'::timestamp) as sec_offset, ".
	"extract(epoch from end_ts - start_ts) as sec_duration, extract(epoch from now() - start_ts) as sec_elapsed, ".
	"extract(epoch from interval '$main::opts{NUM_DAYS} days') as sec_day,recipe, coalesce(aux_weight,0), colour,fixed,(delivery_date-start_ts::date) from xf_jobs where id_machine = $self->{machine_id} and ".
	" (timestamptz '$date', timestamptz '$date' + interval '$main::opts{NUM_DAYS} days') overlaps (start_ts,end_ts) ";
#	warn $q;
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	my $old_bars = $self->{jobs}; 
	$self->{jobs} = [];
	
	for (@$old_bars){
		$self->{bs}->remove($_);
		delete $Planner::UI::widgets{$_->{job_id}};
		$_->destroy;
	}
	my @job_ids;

	my (%counts,%is_bhi);
	while(my $row = $res->fetchrow_arrayref){
		push @job_ids, $$row[0];
		for(@$row){ $_ = '' unless defined; }
		my ($job_id,$start_ts,$end_ts,$comment,$fabric, $have_colour, $sec_offset,$sec_duration,$sec_elapsed,$sec_day,$recipe,$aux_weight,$colour,$fixed,$delivery_date) = @$row;
		my $percentage = 100*$sec_elapsed/$sec_duration;
		$percentage = 100 if $percentage > 100.0;
		$percentage = 0 if $percentage < 0.0;
		
		if ($sec_offset < 0) {
			$sec_duration += $sec_offset;
			$sec_elapsed += $sec_offset;
			$sec_offset = 0;
		}
		if ($sec_offset + $sec_duration > $sec_day){
			$sec_duration = $sec_day - $sec_offset;
		}
		my $frac = $sec_elapsed/$sec_duration;
		$frac = 1.0 if $frac > 1.0;
		$frac = 0.0 if $frac < 0.0;
			
		my $bar;
		my $offset = ($main::opts{PIXELS_PER_MINUTE}*$sec_offset)/60;
		my $width = ($main::opts{PIXELS_PER_MINUTE}*$sec_duration)/60;

#		if($bar = pop @$old_bars){
#			$bar->drag_source_unset;
#			$self->{bs}->move($bar,$offset,$main::opts{ROW_PADDING_UP});
#		} else {
			$bar = new Gtk2::ProgressBar;
			$bar->signal_connect('button-release-event',\&Planner::UI::bar_button_press_handler);
			$self->{bs}->put($bar,$offset,$main::opts{ROW_PADDING_UP});
			$bar->show;
			$bar->signal_connect('drag-drop',\&Planner::UI::bar_drag_drop_handler);
			$bar->signal_connect('drag-begin',\&Planner::UI::bar_drag_begin_handler);
			$bar->signal_connect('drag-end',\&Planner::UI::bar_drag_end_handler);
#		}
		
		$bar->add_events(['button-press-mask','pointer-motion-mask', 'pointer-motion-hint-mask','enter-notify-mask','leave-notify-mask']);
		$bar->signal_connect('enter-notify-event' => \&Planner::UI::bar_mouse_in);
		$bar->signal_connect('leave-notify-event' => \&Planner::UI::bar_mouse_out);
		$counts{$job_id} = 1;
		$bar->{job_id} = $job_id;
		$Planner::UI::widgets{$job_id} = $bar;
		$bar->{sec_duration} = $sec_duration;
		$bar->{orders} = {};
		$bar->{batches} = [];
		$bar->{sum_weight} = $aux_weight;
		$bar->{comment} = $comment;
		$bar->{machine_id} =  $self->{machine_id};
		$bar->{have_colour} = $have_colour;
		$bar->{colour} = $colour;
		$bar->{recipe} = $recipe;
		$bar->{have_fabric} = $fabric;
		$bar->{fixed} = $fixed;
		$bar->{text} = [];
		$bar->{offset} = $offset;
		$bar->{width} = $width;
		$bar->{delivery_date} = $delivery_date;
		$bar->set_size_request($width,$main::opts{ROW_HEIGHT} - $main::opts{ROW_PADDING_DOWN} - $main::opts{ROW_PADDING_UP});
		$bar->set_fraction($frac);
		
		if(($percentage == 0.0 or int($main::opts{ABIDE_TIME}) == 0) and $main::opts{MOVE_JOBS} and !$fixed){
			$bar->drag_source_set(['button1_mask'], ['move'], {target => "grid", flags => 'same-app', info => 0},{target => "job", flags => 'same-app', info => 0});
		} else { # bez tego menu nie chce dzialac :(
			
			$bar->drag_source_set(['button5_mask'], ['move'], {target => "dummy", flags => 'same-app', info => 0},{target => "job", flags => 'same-app', info => 0});

		}
		push @{$self->{jobs}},$bar;
	}
	push @job_ids, -1;
	my $ids = '('.join(',',@job_ids).')';
	pop @job_ids;
	
	$q = 'select x_order.order_no, x_order.order_id,firm_name,job_id,spec_no from (xf_batches natural right join xf_batches_in_job) b  join x_order on (b.order_no = x_order.order_no) join x_customer on (x_customer.id_customer=x_order.customer) where job_id in '.$ids;
	$res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	while(my $row = $res->fetchrow_arrayref){
		
		$Planner::UI::widgets{$$row[3]}->{orders}->{$$row[0]} = $$row[1];
		if($$row[4] == 0 or $counts{$$row[3]} == -1){
			$counts{$$row[3]}=-1;
		}
		$is_bhi{$$row[3]} = 1 if $$row[2] eq 'BHI';
	}
#	warn "short $self->{machine_id}";
	$q = "select order_no||'-'||position||'-'||spec_no||spec_no_suffix,coalesce(weight,0),job_id from xf_batches_in_job natural left join xf_batches where job_id in ".$ids;
	$res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute or warn("Database error: unable to execute query");
	while(my $row = $res->fetchrow_arrayref){
		my $bar = $Planner::UI::widgets{$$row[2]};
		push @{$bar->{batches}},$$row[0].' - '.$$row[1]." kg";
		push @{$bar->{text}}, $$row[0];
		$bar->{sum_weight} += $$row[1];
	}
#	warn "/short";
	use Data::Dumper;
	
	for(@job_ids){
#		if(!$have_colour or !$fabric or !$c){
		my $bar = $Planner::UI::widgets{$_};
		if($bar->{delivery_date} le 2 and $bar->{delivery_date} ne ''){
				$bar->modify_bg('normal', new Gtk2::Gdk::Color(64143,43,43));
				$bar->modify_bg('prelight',new Gtk2::Gdk::Color(64143,43,43));
		} else {
		if(!$bar->{have_colour} or !$bar->{have_fabric} or $counts{$_} == -1 ){
			my $if = $bar->{fixed}?'FIXED_':'';
			if(!$bar->{have_colour} and !$bar->{have_fabric}){
				$bar->modify_bg('normal', $main::opts{'BAR_INCORRECT_'.$if.'BG'});
				$bar->modify_bg('prelight',$main::opts{'BAR_INCORRECT_'.$if.'FG'});
			}elsif(!$bar->{have_colour}){
				$bar->modify_bg('normal', $main::opts{'BAR_NOCOLOUR_'.$if.'BG'});
				$bar->modify_bg('prelight',$main::opts{'BAR_NOCOLOUR_'.$if.'FG'});
			}elsif(!$bar->{have_fabric}){
				$bar->modify_bg('normal', $main::opts{'BAR_NOFABRIC_'.$if.'BG'});
				$bar->modify_bg('prelight',$main::opts{'BAR_NOFABRIC_'.$if.'FG'});
			}	
		} else {
			if($is_bhi{$_}){
				$bar->modify_bg('normal',new Gtk2::Gdk::Color(61143,61143,61143));
				$bar->modify_bg('prelight',new Gtk2::Gdk::Color(18156,66700,45924));
			} else {
				if($bar->{fixed}){
					$bar->modify_bg('normal', $main::opts{BAR_CORRECT_FIXED_BG});
					$bar->modify_bg('prelight',$main::opts{BAR_CORRECT_FIXED_FG});
				}else{
					$bar->modify_bg('normal', $main::opts{BAR_CORRECT_BG});
					$bar->modify_bg('prelight',$main::opts{BAR_CORRECT_FG});
				}
			}
		}
		}
		$bar->{have_colour} = $bar->{have_colour}?'yes':'no';
		$bar->{fabric} = $bar->{fabric}?'yes':'no';
		
		$bar->{recipe} = '' unless defined $bar->{recipe};
		$bar->{colour} = '' unless defined $bar->{colour};
		if($bar->{recipe} ne '' or $bar->{colour} ne ''){
			$bar->{recipe} = "C: $bar->{recipe}/$bar->{colour}\n";
		} else {
			$bar->{recipe} = '';
		}
		
		my @comment = split /\n/,$bar->{comment};
		$comment[0] = '' if !defined $comment[0];
		$bar->set_text(join(", ",@{$bar->{text}})."\n$bar->{recipe}$comment[0]");

	}
}
	
sub add {
#	die "Do not use me!";
#	my$self = shift;
#	my%opts = @_;
#
#	if(!exists($opts{start_ts})){
#		my $q = "select max(end_ts) from xf_jobs where id_machine = $self->{machine_id}";
#		my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
#		$res->execute or warn("Database error: unable to execute query");
#		my $row = $res->fetchrow_arrayref or  warn("Database error: unable to fetch result");
#		$opts{start_ts} = $$row[0];
#	}
#		
#	my $q = " insert into xf_jobs(id_machine,start_ts,end_ts,batch_id,quantity_id,order_id,comments) values(".
#	"($opts{machine_id},timestamptz '$opts{start_ts}',timestamptz '$opts{start_ts}' + interval '$opts{duration}',".
#	"$opts{batch_id},$opts{quantity_id},$opts{order_id},'$opts{comment}');";
#	my $res = $main::dbhandle->do($q) or warn("Database error: unable to create new a job");
#	$self->reload;
}

sub remove {
	my $self = shift;
	my $job_id = shift;
	
	my $q = "delete from xf_jobs where job_id = $job_id";
	my $res = $main::dbhandle->do($q) or warn("Database error: unable to delete the job");
	$self->reload;
}


sub make_ruler {}

sub event_dumper {
	warn Dumper(@_);
}
	
sub destroy {
	my $self = shift;
	$self->{bs}->foreach(sub { $self->{bs}->remove(shift);});
	for(@{$self->{jobs}}){
		delete $Planner::UI::widgets{$_->{job_id}};
		$_->destroy; 
	}
	$self->{bs}->destroy;
	$self->{label_parent}->remove($self->{label});
	$self->{label}->destroy;
}

sub scale {
	my $self = shift;
	my $scale = shift;
	for(@{$self->{jobs}}){
		my ($x,$y,$w,$h) = ($_->{offset}/$scale,$main::opts{ROW_PADDING_UP},$_->{width}/$scale,
			$main::opts{ROW_HEIGHT} - $main::opts{ROW_PADDING_DOWN} - $main::opts{ROW_PADDING_UP});
		($_->{offset},$_->{width}) = ($x,$w);
		$_->set_size_request($w,$h);
		$self->{bs}->move($_,$x,$y);
	}
}


sub DESTROY {
}
1;

