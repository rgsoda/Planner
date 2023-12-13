package pdf_generator;

use LWP::UserAgent;
use threads;
use strict;

my %urls = (	order => 'http://212.160.102.132/sdb_pdf_server/order.php',
				order_close => 'http://212.160.102.132/sdb_pdf_server/order_close.php',
				labdip => 'http://212.160.102.132/sdb_pdf_server/labdip.php',
				invoice => 'http://212.160.102.132/sdb_pdf_server/invoice.php',
				test => 'http://212.160.102.132/sdb_pdf_server/test.php',
				production => 'http://212.160.102.132/sdb_pdf_server/production.php',
				production_period => 'http://212.160.102.132/sdb_pdf_server/production_period.php',
				customer_list => 'http://212.160.102.132/sdb_pdf_server/customer_list.php',
				all_quantitys => 'http://212.160.102.132/sdb_pdf_server/all_quantitys_list.php',
				job_detail => 'http://212.160.102.132/sdb_pdf_server/job_detail.php',
				job_find_report => 'http://212.160.102.132/sdb_pdf_server/job_find_report.php',
				plan => 'http://212.160.102.132/sdb_pdf_server/plan.php',
		);

my $ua = LWP::UserAgent->new;
my $pdf_viewer = 'gpdf';

sub get_display { 
	my ($url,$optref) = @_;
	my $name=time;
	my $req = $ua->post($url,$optref);
    if ($req->is_success) {
		open(OUT,">/tmp/tmppdf_$name.pdf");
        print OUT $req->content."\n";
        close(OUT);
		system("$pdf_viewer /tmp/tmppdf_$name.pdf");
	} else { warn $req->status_line, "\n"; }
}



sub get_order_pdf {
	my $thread = threads->new(\&get_display,$urls{order},{ 'order_id' => pop, 'hide_customer' => $main::opts{HIDE_CUSTOMERS} });
}

sub get_job_detail_pdf {
#	warn Dumper(@_);
	my $thread = threads->new(\&get_display,$urls{job_detail},{ 'order_id' => pop, 'hide_customer' => $main::opts{HIDE_CUSTOMERS} });
}

sub get_invoice_pdf {
	my $thread = threads->new(\&get_display,$urls{invoice},{ 'id_invoice_header' => shift });
}

sub get_labdip_pdf {
	my $thread = threads->new(\&get_display,$urls{labdip},{ 'id_lap_dip' => shift });
}

sub get_test_pdf {
	my $thread = threads->new(\&get_display,$urls{test},{ 'id_test' => shift });
}

sub get_production_pdf {
	my $thread = threads->new(\&get_display,$urls{production},{ '' => shift });
}

sub get_production_period_pdf {
	my $thread = threads->new(\&get_display,$urls{production_period},{ 'od' => shift, 'do' => shift });
}

sub get_customer_list_pdf {
	my $thread = threads->new(\&get_display,$urls{customer_list},{ 'search' => shift });
}

sub get_all_quantitys_pdf {
	my $thread = threads->new(\&get_display,$urls{all_quantitys},{ 'search' => shift });
}

sub get_order_close_pdf {
	my $thread = threads->new(\&get_display,$urls{order_close},{ 'order_id' => shift });
}

sub get_plan_pdf {
	my $thread = threads->new(\&get_display,$urls{plan},{ 'order_id' => shift });
}

sub job_find_report {
	my $h = {};
	for(my $i = 0; $_ = pop ; $i++){
		$h->{"jobid[$i]"} = $_;
	}	
	my $thread = threads->new(\&get_display,$urls{job_find_report},$h, @_);
}


	
1;

