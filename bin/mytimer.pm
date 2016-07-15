# timer class
#
package mytimer;
#
sub new {
    my $class = shift;
    my ($fileno, $delta, $id, $label) = @_;
    #
    my $self = {};
    $self->{fileno} = $fileno;
    $self->{delta} = $delta;
    $self->{expire} = time() + $delta;
    $self->{id} = $id;
    $self->{label} = $label;
    $self->{heap} = 0;
    #
    bless $self, $class;
    #
    return($self);
}
#
sub cmp {
    my ($self, $other) = @_;
    my $dexp = $self->{expire} - $other->{expire};
    if ($dexp != 0) {
        return($dexp);
    } else {
        return($self->{id} - $other->{id});
    }
}
#
sub heap {
    my $self = shift;
    $self->{heap} = shift if @_;
    return($self->{heap});
}
#
sub rw_fileno {
    my $self = shift;
    $self->{fileno} = shift if @_;
    return($self->{fileno});
}
sub rw_id {
    my $self = shift;
    $self->{id} = shift if @_;
    return($self->{id});
}
sub rw_expire {
    my $self = shift;
    $self->{expire} = shift if @_;
    return($self->{expire});
}
sub rw_label {
    my $self = shift;
    $self->{label} = shift if @_;
    return($self->{label});
}
#
sub dump {
    my $self = shift;
    my $log_fh = shift;
    my $class = ref($self);
    #
    if (defined($log_fh))
    {
        print $log_fh "\n";
        print $log_fh "ref class = $class\n";
        print $log_fh "fileno = ".$self->{fileno}."\n";
        print $log_fh "delta = ".$self->{delta}."\n";
        print $log_fh "expire = ".$self->{expire}."\n";
        print $log_fh "id = ".$self->{id}."\n";
        print $log_fh "label = ".$self->{label}."\n";
        print $log_fh "heap = ".$self->{heap}."\n";
    }
    else
    {
        print "\n";
        print "ref class = $class\n";
        print "fileno = ".$self->{fileno}."\n";
        print "delta = ".$self->{delta}."\n";
        print "expire = ".$self->{expire}."\n";
        print "id = ".$self->{id}."\n";
        print "label = ".$self->{label}."\n";
        print "heap = ".$self->{heap}."\n";
    }
}
# exit with success
1;
