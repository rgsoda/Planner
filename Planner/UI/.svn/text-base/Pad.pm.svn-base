package Planner::UI::Pad;
use strict;
##use warnings;
use Gtk2;

sub new {
    my $class = shift;

    die "no \$dbhandle declared in main" unless defined $main::dbhandle;
    my $self = {
        bar_parent => shift,
        jobs       => [],
        bs         => new Gtk2::Fixed    # bar space
    };

    bless $self, $class;

    $self->{bs}
      ->set_size_request( $main::opts{PAD_WIDTH}, $main::opts{PAD_HEIGHT} );
    $self->{bs}->drag_dest_set( 'all', ['move'],
        { target => 'grid', flags => 'same-app', info => 0 } );
    $self->{bs}->signal_connect( 'drag-motion',
        \&Planner::UI::fixed_drag_motion_handler );
    $self->{bs}
      ->signal_connect( 'drag-drop', \&Planner::UI::pad_drag_drop_handler );
    $self->{bs}->{ispad} = 0;

    $self->{bar_parent}->pack_start( $self->{bs}, 1, 1, 0 );
    $self->{bs}->drag_dest_set( 'all', ['move'],
        { 'target' => "grid", 'flags' => 'same-app', 'info' => 0 } );
    return $self;
}

sub reload {
    my $self = shift;

    my $q =
"select job_id, start_ts, end_ts, comment, fabric,have_colour, 0 as sec_offset, "
      . "extract(epoch from end_ts - start_ts) as sec_duration, 0 as sec_elapsed, comment,recipe,coalesce(aux_weight,0),colour "
      . "from xf_jobs where id_machine = -1";

    #	warn $q;

    my $res = $main::dbhandle->prepare($q)
      or warn("Database error: unable to prepare query");
    $res->execute or warn("Database error: unable to execute query");
    my $old_bars = $self->{jobs};
    $self->{jobs} = [];

    for (@$old_bars) {
        $self->{bs}->remove($_);
        $_->destroy;
    }

    my $y_offset = 0;
    while ( my $row = $res->fetchrow_arrayref ) {
        for (@$row) { $_ = '' unless defined; }
        my (
            $job_id,      $start_ts,    $end_ts,     $comment,
            $fabric,      $have_colour, $sec_offset, $sec_duration,
            $sec_elapsed, $sec_day,     $recipe,     $aux_weight,
            $colour
          )
          = @$row;

        my $bar;

        #	if($bar = pop @$old_bars){
        #		$bar->drag_source_unset;
        #		$self->{bs}->move($bar,0,$y_offset);
        #	} else {

        $bar = new Gtk2::ProgressBar;
        $self->{bs}->put( $bar, 0, $y_offset );
        $bar->show;
        $bar->signal_connect( 'button-release-event',
            \&Planner::UI::bar_button_press_handler );
        $bar->signal_connect( 'drag-drop',
            \&Planner::UI::bar_drag_drop_handler );
        $bar->signal_connect( 'drag-begin',
            \&Planner::UI::bar_drag_begin_handler );
        $bar->signal_connect( 'drag-end', \&Planner::UI::bar_drag_end_handler );

        #	}

        $bar->add_events(
            [
                'button-press-mask',        'pointer-motion-mask',
                'pointer-motion-hint-mask', 'enter-notify-mask',
                'leave-notify-mask'
            ]
        );
        $bar->signal_connect(
            'enter-notify-event' => \&Planner::UI::bar_mouse_in );
        $bar->signal_connect(
            'leave-notify-event' => \&Planner::UI::bar_mouse_out );

        $bar->{job_id}       = $job_id;
        $bar->{sec_duration} = $sec_duration;
        $bar->{orders}       = {};
        $bar->{batches}      = [];
        $bar->{sum_weight}   = $aux_weight;
        $bar->{comment}      = $comment;
        $bar->{machine_id}   = -1;

        $bar->set_size_request( -1,
            $main::opts{ROW_HEIGHT} - $main::opts{ROW_PADDING_DOWN} -
              $main::opts{ROW_PADDING_UP} );

        if ( $main::opts{MOVE_JOBS} ) {
            $bar->drag_source_set(
                ['button1_mask'],
                ['move'],
                { target => "grid", flags => 'same-app', info => 0 },
                { target => "job",  flags => 'same-app', info => 0 }
            );
        }

        warn
"=============================== job orders ===============================";
        $main::queries{job_orders}->execute($job_id)
          or warn("Database error: unable to execute query");
        warn
"============================== /job orders ===============================";

        my $c      = 0;
        my $is_bhi = 0;
        while ( my $det = $main::queries{job_orders}->fetchrow_arrayref ) {
            $bar->{orders}->{ $$det[0] } = $$det[1];
            $c++;
            $is_bhi = 1 if $$det[2] eq 'BHI';
        }

        #               if(!$have_colour or !$fabric or !$c){
        if ( !$have_colour or !$c ) {
            $bar->modify_bg( 'normal',
                new Gtk2::Gdk::Color( 60000, 30000, 30000 ) );
            $bar->modify_bg( 'prelight',
                new Gtk2::Gdk::Color( 65000, 0000, 0000 ) );
        }
        else {
            if ($is_bhi) {
                $bar->modify_bg( 'normal',
                    new Gtk2::Gdk::Color( 61143, 61143, 61143 ) );
                $bar->modify_bg( 'prelight',
                    new Gtk2::Gdk::Color( 18156, 66700, 45924 ) );
            }
            else {
                $bar->modify_bg( 'normal',
                    new Gtk2::Gdk::Color( 61143, 61143, 61143 ) );
                $bar->modify_bg( 'prelight',
                    new Gtk2::Gdk::Color( 18156, 26700, 45924 ) );
            }
        }
        $have_colour = $have_colour ? 'yes' : 'no';
        $fabric      = $fabric      ? 'yes' : 'no';
        my @text;

        #		warn "================== job_batches_short =====================";
        $main::queries{job_batches_short}->execute( $bar->{job_id} );

        #		warn "//";
        while ( my $row = $main::queries{job_batches_short}->fetchrow_arrayref )
        {
            push @{ $bar->{batches} }, $$row[0] . ' - ' . $$row[1] . " kg";
            push @text, $$row[0];
            $bar->{sum_weight} += $$row[1];
        }
        $recipe = '' unless defined $recipe;
        $colour = '' unless defined $colour;
        if ( $recipe ne '' or $colour ne '' ) {
            $recipe = "C: $recipe/$colour\n";
        }
        else {
            $recipe = '';
        }

       #		$comment = substr ($comment,0, index ($comment,"\n")+1); #=~ s/\n.*//;
        my @comment = split /\n/, $comment;
        $comment[0] = '' if !defined $comment[0];
        $bar->set_text( join( ", ", @text ) . "\n$recipe$comment[0]" );

        push @{ $self->{jobs} }, $bar;
    }
    continue { $y_offset += $main::opts{ROW_HEIGHT} + 2; }

    #	for (@$old_bars){
    #		$self->{bs}->remove($_);
    #		$_->destroy;
    #	}

}

sub make_ruler { }

sub event_dumper {
    warn Dumper(@_);
}

sub destroy {

    # do nothing
}

sub scale {

    # do nothing
}

1;

