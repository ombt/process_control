# task-specific data
#
package mytaskdata;
#
use myconstants;
#
# create a data object for given key
#
sub new
{
    my $class = shift;
    #
    my $self = {};
    $self->{data} = {};
    #
    if (scalar(@_) > 0)
    {
        my $id = shift;
        $self->{data}->{$id} = { id => $id };
    }
    #
    bless $self, $class;
    #
    return($self);
}
#
sub iterator
{
    my $self = shift;
    my $sort_by = shift;
    #
    my $pdata = $self->{data};
    my @keys = ();
    #
    if (defined($sort_by))
    {
        if ($sort_by eq 'n')
        {
            @keys = sort { $a <=> $b } keys %{${pdata}};
        }
        else
        {
            @keys = sort keys %{${pdata}};
        }
    }
    else
    {
        @keys = keys %{${pdata}};
    }
    #
    my $max = scalar(@keys);
    my $idx = -1;
    #
    return sub {
        return undef if (++$idx >= $max);
        return $keys[$idx];
    };
}
#
sub clear
{
    my $self = shift;
    $self->{data} = {};
}
#
sub data
{
    my $self = shift;
    return $self->{data};
}
#
sub get
{
    my $self = shift;
    #
    # trying to avoid autovivification. have to check each 
    # level before the next level.
    #
    if (scalar(@_) == 1)
    {
        my $id = shift;
        return $self->{data}->{$id}
            if (exists($self->{data}->{$id}));
    }
    elsif (scalar(@_) == 2)
    {
        my $id = shift;
        my $key = shift;
        return $self->{data}->{$id}->{$key}
            if ((exists($self->{data}->{$id})) &&
                (exists($self->{data}->{$id}->{$key})));
    }
    #
    return undef;
}
#
sub set
{
    my $self = shift;
    if (scalar(@_) == 2)
    {
        my $id = shift;
        my $data = shift;
        #
        $self->{data}->{$id} = $data;
        return $self->{data}->{$id};
    }
    elsif (scalar(@_) == 3)
    {
        my $id = shift;
        my $key = shift;
        my $value = shift;
        #
        $self->{data}->{$id}->{$key} = $value;
        return $self->{data}->{$id}->{$key};
    }
    else
    {
        return undef;
    }
}
#
sub exists
{
    my $self = shift;
    #
    # trying to avoid autovivification. have to check each 
    # level before the next level.
    #
    if (scalar(@_) == 1)
    {
        my $id = shift;
        return TRUE if (exists($self->{data}->{$id}));
    }
    elsif (scalar(@_) == 2)
    {
        my $id = shift;
        my $key = shift;
        return TRUE if ((exists($self->{data}->{$id})) &&
                        (exists($self->{data}->{$id}->{$key})));
    }
    #
    return FALSE;
}
#
sub allocate
{
    my $self = shift;
    my $id = shift;
    #
    delete $self->{data}->{$id} if (exists($self->{data}->{$id}));
    $self->{data}->{$id} = { id => $id };
}
#
sub deallocate
{
    my $self = shift;
    my $id = shift;
    #
    delete $self->{data}->{$id} if (exists($self->{data}->{$id}));
}
#
sub reallocate
{
    my $self = shift;
    my $id = shift;
    #
    delete $self->{data}->{$id} if (exists($self->{data}->{$id}));
    $self->{data}->{$id} = { id => $id };
}
#
# exit with success
#
1;
