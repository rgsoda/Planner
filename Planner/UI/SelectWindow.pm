package Planner::UI::SelectWindow;
use Gtk2;
use strict;
use warnings;
use DBI;
use Gtk2::SimpleList;


sub new_position {
	my $class = shift;
	my $self = 	{
				tree => shift,
				path => shift,
				column => shift,
				edit => shift,
			};
	$self->{model} = $self->{tree}->get_model;
	$self->{iter} = $self->{model}->get_iter($self->{path});
	bless $self,$class;

	$self->{window} = new Gtk2::Window('popup');
	$self->{window}->set_title("WorkPlanner");
	$self->{window}->set_modal(1);
	$self->{window}->set_position('mouse');
	$self->{window}->set_transient_for($main::ui->{window});
	$self->{window}->set_default_size(250,120);
	
        my $scroll = new Gtk2::ScrolledWindow;
	$scroll->set_policy('automatic','automatic');
	$self->{position_list} = new Gtk2::SimpleList('Pos'=>'int','Colour'=>'text','Order'=>'int');
	$scroll->add_with_viewport($self->{position_list});
	$self->{window}->add($scroll);
	$self->{window}->show_all;
	
	($self->{order_no}) = ($self->{model}->get_value($self->{iter},0));
	my $q = 'select position,quantity_colour,x_order.order_no from x_quantity left join x_order on (x_order.order_no = x_quantity.order_no) where 
		(x_order.order_no = '.int($self->{order_no}).' or customer_order_no = '.int($self->{order_no}).') 
		and x_quantity.state <> 2 order by position';
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute;
	my $i = 0; my $sel;
	my ($pos) = ($self->{model}->get_value($self->{iter},1));
	while (my $row = $res->fetchrow_arrayref){
		$sel = $i if($pos == $$row[0]);
		push @{$self->{position_list}->{data}},[@$row];
	} continue {$i++;}
	push @{$self->{position_list}->{data}},['0',''];
	$self->{position_list}->signal_connect(row_activated => \&position_row_activated,$self);
	$self->{position_list}->select($sel);
	return $self;
}
sub new_spec {
	my $class = shift;
	my $self = 	{
				tree => shift,
				path => shift,
				column => shift,
				edit => shift,
			};
	$self->{model} = $self->{tree}->get_model;
	$self->{iter} = $self->{model}->get_iter($self->{path});
	bless $self,$class;

	$self->{window} = new Gtk2::Window('popup');
	$self->{window}->set_title("WorkPlanner");
	$self->{window}->set_modal(1);
	$self->{window}->set_position('mouse');
	$self->{window}->set_transient_for($main::ui->{window});
	$self->{window}->set_default_size(200,120);
	
        my $scroll = new Gtk2::ScrolledWindow;
	$scroll->set_policy('automatic','automatic');
	$self->{batch_list} = new Gtk2::SimpleList('Batch'=>'int','Weight'=>'text');
	$scroll->add_with_viewport($self->{batch_list});
	my $hbox = new Gtk2::HBox;
	my $vbox = new Gtk2::VBox;

	
	$self->{window}->add($vbox);
	$vbox->pack_start($scroll,1,1,0);
	$vbox->pack_start($hbox,0,0,0);
	

	$hbox->pack_start($self->{entry} = new Gtk2::Entry,0,0,0);
	$hbox->pack_start($self->{update} = new_from_stock Gtk2::Button('gtk-apply'),0,0,0);
	$self->{update}->signal_connect(pressed => \&apply_pressed, $self);
	

	
	$self->{window}->show_all;
	
	($self->{order_no},$self->{position}) = ($self->{model}->get_value($self->{iter},0,1));
	my $q = 'select spec_no,sum(weight)||\' kg\' from x_stock_raw join x_quantity on 
		(x_quantity.quantity_id=x_stock_raw.colour_id)
		left join x_order on (x_order.order_no=x_quantity.order_no) where 
		(x_order.order_no = '.int($self->{order_no}).' or x_order.customer_order_no = '.int($self->{order_no}).')
		and position = '.int($self->{position}).' group by spec_no;';
	my $res = $main::dbhandle->prepare($q) or warn("Database error: unable to prepare query");
	$res->execute;
	my $i = 0; my $sel;
	my ($bcno) = ($self->{model}->get_value($self->{iter},2));
	while (my $row = $res->fetchrow_arrayref){
		$sel = $i if($bcno == $$row[0]);
		push @{$self->{batch_list}->{data}},[@$row];
	} continue {$i++;}
	push @{$self->{batch_list}->{data}},['0',''];
	$self->{batch_list}->signal_connect(row_activated => \&batch_row_activated,$self);
	$self->{batch_list}->select($sel);
	$self->{entry}->set_text($bcno);
	return $self;
}

sub position_row_activated {
	my $self = pop;
	my ($tree,$path,$column) = @_;
	my $model = $tree->get_model;
	my $iter = $model->get_iter($path);
	my ($pos,$col) = $model->get_value($iter,0,1);
	$self->{model}->set($self->{iter},1,$pos);
	$self->{edit}->{colour}->set_text($col);
	$self->{window}->destroy;
}

sub batch_row_activated {
	my $self = pop;
	my ($tree,$path,$column) = @_;
	my $model = $tree->get_model;
	my $iter = $model->get_iter($path);
	my ($bcno,$weight) = $model->get_value($iter,0,1);
	$self->{model}->set($self->{iter},2,$bcno,4,$weight);
	$self->{window}->destroy;
}

sub apply_pressed {
	my $self = pop;
	my $bcno = int($self->{entry}->get_text);
	$self->{model}->set($self->{iter},2,$bcno);
	$self->{window}->destroy;


}
		



1;
