#!/usr/bin/perl

use DBI;
use Planner::UI;
use Gtk2;
use Lock;

Gtk2->init; 

unlink </tmp/tmppdf_*.pdf>;

sub days_in_month {
	my @dim = (0,31,28,31,30,31,30,31,31,30,31,30,31);
	my ($y,$m,$d) = @_;
	my $is_leap = 0;
	$is_leap = 1 if !$y%4;
	$is_leap = 0 if !$y%100;
	$is_leap = 1 if !$y%400;
	return 29 if $m == 2 and $is_leap;
	return $dim[$m];
}


my %cmdline = @ARGV;
our %defaults = (	
			DB_NAME			=>	'sontex2',
			DB_HOST			=>	'212.160.102.132',
			DB_USERNAME		=>	'sontex',
			DB_PASSWORD		=>	'sontex',
			PIXELS_PER_MINUTE 	=>	0.3,
			NUM_DAYS		=>	3,
			ROW_HEIGHT		=>	45,
			REFRESH_DELAY 		=>	900000,
			TIME_HEIGHT		=>	35,
			ROW_PADDING_UP		=>	0,
			ROW_PADDING_DOWN	=>	0,
			PAD_WIDTH		=>	200,
			PAD_HEIGHT		=>	-1, #300,
			HIDE_CUSTOMERS 		=>	0,
			MENU_EDIT		=>	1,
			MENU_ADJUST		=>	1,
			MENU_ORDER		=>	1,
			MENU_DETAILS		=>	1,
			NEW_JOBS		=>	1,
			MOVE_JOBS		=>	1,
			SKIP_HOURS		=>	8,
			ABIDE_TIME		=>	1,
			ABIDE_OVERLAP		=>	1,

			BAR_NOFABRIC_FG		=>      new Gtk2::Gdk::Color(59000,52000,28000),
			BAR_NOFABRIC_BG		=>      new Gtk2::Gdk::Color(59000,52000,36000),
			
			BAR_INCORRECT_FG	=>      new Gtk2::Gdk::Color(42000,56000,50000),
			BAR_INCORRECT_BG	=>      new Gtk2::Gdk::Color(42000,56000,58500),
			
			BAR_NOCOLOUR_FG		=>      new Gtk2::Gdk::Color(48000,60000,40000),
			BAR_NOCOLOUR_BG		=>      new Gtk2::Gdk::Color(48000,60000,47000),
			
			BAR_NOFABRIC_FIXED_FG	=>      new Gtk2::Gdk::Color(44000,39000,20000),
			BAR_NOFABRIC_FIXED_BG	=>      new Gtk2::Gdk::Color(44000,39000,26000),
			
			BAR_INCORRECT_FIXED_FG	=>      new Gtk2::Gdk::Color(30500,41000,37500),
			BAR_INCORRECT_FIXED_BG	=>      new Gtk2::Gdk::Color(30500,41000,43500),
			
			BAR_NOCOLOUR_FIXED_FG	=>      new Gtk2::Gdk::Color(31000,45000,23000),
			BAR_NOCOLOUR_FIXED_BG	=>      new Gtk2::Gdk::Color(31000,45000,30000),
			
#			BAR_INCORRECT_FG	=>      new Gtk2::Gdk::Color(60000,00000,00000),
#			BAR_INCORRECT_BG	=>      new Gtk2::Gdk::Color(60000,30000,30000),
			
			BAR_CORRECT_FG		=>      new Gtk2::Gdk::Color(18156,26700,45924),
			BAR_CORRECT_BG		=>      new Gtk2::Gdk::Color(61143,61143,61143),
			BAR_CORRECT_FIXED_FG	=>      new Gtk2::Gdk::Color(18156,26700,45924),
			BAR_CORRECT_FIXED_BG	=>      new Gtk2::Gdk::Color(41143,41143,41143),
			BAR_HIGHLIGHT_FG	=>      new Gtk2::Gdk::Color(18156,56700,45924),
			BAR_HIGHLIGHT_BG	=>      new Gtk2::Gdk::Color(21143,61143,61143),
			FIND_PRINT		=>	0,
	);

our %opts = (%defaults,%cmdline);
#for my $k (qw/BAR_INCORRECT_FG BAR_INCORRECT_BG BAR_CORRECT_FG BAR_CORRECT_BG BAR_HIGHLIGHT_FG BAR_HIGHLIGHT_BG/){
#	if(exists $cmdline{$k}){
#		$opts{$k} = new Gtk2::Gdk::Color(map {$_*257} split /,/,$cmdline{$k} );
#		delete $cmdline{$k};
#	}
#}

our $dbhandle = DBI->connect("dbi:Pg:dbname=$opts{DB_NAME};host=$opts{DB_HOST}", $opts{DB_USERNAME} , $opts{DB_PASSWORD}, { RaiseError => 1, AutoCommit => 1 }) or
		warn "AAARRGHHH! Unable to connect to the database";

our %queries =	(
		job_orders =>
			$dbhandle->prepare('select x_order.order_no, x_order.order_id,firm_name from xf_batches natural join xf_batches_in_job  join x_order on (xf_batches.order_no = x_order.order_no) join x_customer on (x_customer.id_customer=x_order.customer) where job_id = ?'),
		job_batches =>
			$dbhandle->prepare('select order_no,position,spec_no,spec_no_suffix,coalesce(weight::text,\'---\')||\' kg\' from xf_batches_in_job natural left join xf_batches where job_id = ?'),
		job_batches_short =>
			$dbhandle->prepare('select order_no||\'-\'||position||\'-\'||spec_no||spec_no_suffix,coalesce(weight,0),job_id from xf_batches_in_job natural left join xf_batches where job_id = ?'),
		job_all_batches =>
#			$dbhandle->prepare('select b.order_no,b.position,b.spec_no,b.spec_no_suffix,q.quantity_colour,d.quality_no from xf_batches_in_job b join x_quantity q on (q.order_no=b.order_no,q.position=b.position) join x_order o on (o.order_no = b.order_no) join x_quality d on (o.quality = d.quality_id) where b.job_id = ?'),
			$dbhandle->prepare('select b.order_no,b.position,b.spec_no,b.spec_no_suffix,q.quantity_colour,d.quality_no from xf_batches_in_job b,x_quantity q, x_order o,x_quality d  where o.quality = d.quality_id and q.position=b.position and q.order_no=b.order_no and o.order_no = b.order_no and b.job_id = ?'),
	); 

#for(keys %cmdline){
#	$opts{$_} = $cmdline{$_};
#}
#use Data::Dumper::Simple;
#warn Dumper(%opts);
$opts{PIXELS_PER_HOUR} = 60*$opts{PIXELS_PER_MINUTE};
$opts{PIXELS_PER_DAY} = 24*$opts{PIXELS_PER_HOUR};

$opts{ROW_WIDTH} = 24 * $opts{PIXELS_PER_HOUR} * $opts{NUM_DAYS};

my $lock = new Lock('planner');
our $ui = new Planner::UI($dbhandle);

$ui->{window}->show_all;
Gtk2->main;

$dbhandle->disconnect;

0;

