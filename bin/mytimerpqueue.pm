# priority queue object implementation using a binary heap.
#
package mytimerpqueue;
#
sub new
{
    my $class = shift;
    #
    my $self = {};
    $self->{heapsize} = 1000;
    $self->{data} = [];
    $self->{nextelement} = 0;
    $self->{count} = 0;
    bless $self, $class;
    #
    return($self);
}
#
sub is_empty
{
    my $self = shift;
    return($self->{nextelement} == 0);
}
#
sub heap_size
{
    my $self = shift;
    $self->{heapsize} = shift if @_;
    return($self->{heapsize});
}
sub data
{
    my $self = shift;
    $self->{data} = shift if @_;
    return($self->{data});
}
sub count
{
    my $self = shift;
    return($self->{count});
}
sub next_element
{
    my $self = shift;
    $self->{nextelement} = shift if @_;
    return($self->{nextelement});
}
#
sub sift_up
{
    my ($self, $element) = @_;
    #
    return if ($element == 0);
    #
    my $parent = int(($element-1)/2);
    my $status = $self->{data}[$element]->cmp($self->{data}[$parent]);
    return if ($status >= 0);
    #
    @{$self->{data}}[$element, $parent] = 
        @{$self->{data}}[$parent, $element];
    $self->{data}[$element]->heap($element);
    $self->{data}[$parent]->heap($parent);
    $self->sift_up($parent);
    #
    return;
}
#
sub enqueue
{
    #
    my ($self, $data) = @_;
    my $pos = undef;
    #
    defined($data) or die "enqueue - undefined data.";
    #
    if ($self->{nextelement} == $self->{heapsize})
    {
        $self->{heapsize} *= 2;
    }
    #
    $self->{data}[$self->{nextelement}] = $data;
    $self->{data}[$self->{nextelement}]->heap($self->{nextelement});
    $self->sift_up($self->{nextelement});
    $self->{nextelement} += 1;
    $self->{count} += 1;
    #
    return(1);
}
#
sub remove
{
    my ($self, $pdata) = @_;
    #
    # verify we have the correct one to delete.
    #
    my $pdata2;
    if (($self->getNth($pdata->heap, \$pdata2) != 0) &&
        ($pdata->cmp($pdata2) == 0))
    {
        return($self->removeNth($pdata->heap, \$pdata2));
    }
    return(0);
}
#
sub removeNth
{
    my ($self, $element, $pdata) = @_;
    #
    return(0) if ($element >= $self->{nextelement});
    #
    $$pdata = $self->{data}[$element];
    $self->{nextelement} -= 1;
    $self->{count} -= 1;
    if ($element != $self->{nextelement})
    {
        $self->{data}[$element] = 
            $self->{data}[$self->{nextelement}];
        $self->{data}[$element]->heap($element);
        $self->sift_down($element);
    }
    return(1);
}
#
sub sift_down
{
    my ($self, $parent) = @_;
    #
    my $leftchild = int(2*$parent+1);
    my $rightchild = $leftchild+1;
    #
    return if ($leftchild >= $self->{nextelement});
    #
    my $leftcmp = $self->{data}[$parent]->cmp(
                $self->{data}[$leftchild]);
    if ($rightchild >= $self->{nextelement})
    {
        if ($leftcmp > 0)
        {
            @{$self->{data}}[$leftchild, $parent] = 
                @{$self->{data}}[$parent, $leftchild];
            $self->{data}[$leftchild]->heap($leftchild);
            $self->{data}[$parent]->heap($parent);
        }
        return;
    }
    #
    my $rightcmp = $self->{data}[$parent]->cmp(
                $self->{data}[$rightchild]);
    if ($leftcmp > 0 || $rightcmp > 0)
    {
        my $leftrightcmp = $self->{data}[$leftchild]->cmp(
            $self->{data}[$rightchild]);
        my $swapelement;
        if ($leftrightcmp < 0)
        {
            $swapelement = $leftchild;
        }
        else
        {
            $swapelement = $rightchild;
        }
        @{$self->{data}}[$swapelement, $parent] = 
            @{$self->{data}}[$parent, $swapelement];
        $self->{data}[$swapelement]->heap($swapelement);
        $self->{data}[$parent]->heap($parent);
        $self->sift_down($swapelement);
        return;
    }
    return;
}
#
sub dequeue
{
    my ($self, $pdata) = @_;
    return($self->removeNth(0, $pdata));
}
#
sub front
{
    my ($self, $pdata) = @_;
    if (!$self->is_empty())
    {
        $$pdata = $self->{data}[0];
        return(1);
    }
    else
    {
        return(0);
    }
}
#
sub getNth
{
    my ($self, $element, $pdata) = @_;
    return(0) if ($element >= $self->{nextelement});
    if (!$self->is_empty())
    {
        $$pdata = $self->{data}[$element];
        return(1);
    }
    else
    {
        return(0);
    }
}
#
sub dump
{
    my $self = shift;
    my $log_fh = shift;
    #
    if (defined($log_fh))
    {
        for (my $i=0; $i<$self->{count}; ${i}++)
        {
            print $log_fh "array[$i] = \n";
            $self->{data}[$i]->dump($log_fh);
        }
    }
    else
    {
        for (my $i=0; $i<$self->{count}; ${i}++)
        {
            print "array[$i] = \n";
            $self->{data}[$i]->dump();
        
        }
    }
}
#
# exit with success
1;
