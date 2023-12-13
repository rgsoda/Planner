package Planner::UI::Timeline;
use strict;
use warnings;
use Gtk2;


sub new {
	my $class = shift;
	
	my $self = 	{ 
				label_parent => shift,
				bar_parent => shift,
				time_grid => shift,
				label => new Gtk2::Label,
#				dbhandle => $main::dbhandle,
				bs => new Gtk2::Fixed		# bar space
			};
		
	bless $self,$class;
	$self->{label}->set_size_request(-1, $main::opts{TIME_HEIGHT});
	$self->{label_parent}->pack_start( $self->{label},0,0,0);
	$self->{label_parent}->pack_start( new Gtk2::HSeparator,0,1,0);
		
	$self->{bs}->set_size_request(-1, $main::opts{TIME_HEIGHT});
	$self->{bar_parent}->pack_start( $self->{bs},0,1,0);
	$self->{bar_parent}->pack_start( new Gtk2::HSeparator,0,1,0);
	$self->{font_desc} = Gtk2::Pango::FontDescription->from_string ("sans");

	$self->{bs}->signal_connect( 'configure_event', \&make_ruler,$self);
	$self->{bs}->signal_connect( 'expose-event', \&make_ruler,$self);

	

	return $self
}

sub make_me_invalid {
#	use Data::Dumper::Simple;
#	warn Dumper(@_);
	my $self = shift;
	
#	my $win = $self->{bs}->window;
#	my $rect = $win->get_frame_extents;
#	warn Dumper($rect->x,$rect->y,$rect->width,$rect->height);
#	$win->invalidate_rect($rect,0);
#	$win->process_all_updates;
#	$self->{bs}->unrealize;
#	$self->{bs}->event(new Gtk2::Gdk::Event('expose'));
	make_ruler($self->{bs},undef,$self);

}


sub make_ruler {
#	use Data::Dumper::Simple;
#	warn Dumper(@_);
	my ($widget,undef,$self) = @_;
	my $drawable = $widget->window;
	my $adj =  $self->{time_grid}->get_hadjustment;
#	my ($show_from,$page) = ($adj->get_value,$adj->page_size);
        
	my($year,$month,$day) = ($main::ui->{date} =~ /(\d+)-(\d+)-(\d+)$/);
	


	my $darkgray = new Gtk2::Gdk::Color(50000,50000,50000 );
	my $gc_dg = new Gtk2::Gdk::GC($drawable);
	my $lightgray = new Gtk2::Gdk::Color(60000,60000,60000 );
	my $gc_lg = new Gtk2::Gdk::GC($drawable);
	$gc_dg->set_rgb_fg_color ($darkgray);
	$gc_lg->set_rgb_fg_color ($lightgray);
	for(1 .. $main::opts{NUM_DAYS}){
		#next if $_%2;
		$drawable->draw_rectangle(($_%2)?$gc_lg:$gc_dg,1,($_-1) * $main::opts{PIXELS_PER_DAY},
						0,$main::opts{PIXELS_PER_DAY}, $main::opts{TIME_HEIGHT});
	}

	
	my $red = new Gtk2::Gdk::Color(65000,0,0 );
	my $blue = new Gtk2::Gdk::Color(0,0,65000 );
	my $gc_red = new Gtk2::Gdk::GC($drawable);
	my $gc_blue = new Gtk2::Gdk::GC($drawable);
	$gc_red->set_rgb_fg_color ($red);
	$gc_blue->set_rgb_fg_color ($blue);
	
#	$show_from -= $show_from % $main::opts{PIXELS_PER_HOUR};
#	my $show_to = $show_from + $page + $main::opts{PIXELS_PER_HOUR};

	my ($show_from,$show_to) = (0,$adj->upper);
	
	my $hoffset = int($show_from/$main::opts{PIXELS_PER_HOUR});
	for(my ($x,$h) = ($show_from,$hoffset) ; $x < $show_to; $x+=$main::opts{PIXELS_PER_HOUR},$h=$h+1){

		
		unless($h % 24){
			$drawable->draw_line( $gc_blue, $x, 2, $x, 1000 );
		}
		
		next unless $h % $main::opts{SKIP_HOURS} == 0;
		my ($y,$m,$d) = ($year,$month,$day);
		my $doffset = int($h/24);
		while($doffset > 0){
			my $dim = &main::days_in_month($y,$m,$d);
			if($d + $doffset > $dim){
				$doffset -= $dim - $d + 1;
				$d = 1;
				if($m == 12){ $y++; $m = 1; } 
				else { $m++;}
			} else {
				$d += $doffset;
				$doffset = 0;
			}
		}
	
		$drawable->draw_line( $gc_red, $x, 2, $x, $main::opts{TIME_HEIGHT}-2 );
		my $layout = $widget->create_pango_layout(sprintf("%02d-%02d\n%02d:00",$d,$m,$h%24));
		$layout->set_font_description ($self->{font_desc});
		$drawable->draw_layout($gc_blue,$x + 10,0,$layout);
	}
}




	
#asub DESTROY {
#	my $self = shift;
#	print STDERR, "$self->{machine_id} destroyed

1;

