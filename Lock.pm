package Lock;

use Gtk2;

use strict;
use warnings;

my $message = <<MESSAGE;
It looks like the program is 
already running. 
Start another instance?
MESSAGE
sub new {
	my $class = shift;
	
	my $self = { name => shift, parent => shift};
	

	$self->{file} = "/tmp/$self->{name}_$ENV{USER}_lock";
	if(-e $self->{file}){
		my $dialog = new Gtk2::Dialog("Database already running?",$self->{parent},
				['modal','destroy-with-parent'],
				'gtk-no'	=>	1,
				'gtk-yes'	=>	0);
		my $label = new Gtk2::Label($message);
		$dialog->vbox->add($label);
		$label->show;
		
		
		use Data::Dumper;
		$dialog->signal_connect(response => 
						sub { 
							my ($dialog,$no) = @_;
							if($no){
								exit 24;
							}
						});
		$dialog->run;
		$dialog->destroy;
	} else {
		open LOCKFILE, '>',$self->{file};
		print LOCKFILE $$;
		close LOCKFILE;
	}
	bless $self,$class;
}

sub DESTROY {
	my $self = shift;
	unlink $self->{file};
}

1;
