#!/usr/bin/perl -w
#
# Copyright (C) 2010, OMBT LLC and Mike A. Rumore
# All rights reserved.
# Contact: Mike A. Rumore, (mike.a.rumore@gmail.com)
#
#
use strict;
#
use FileHandle;
use File::Basename;
use Getopt::Std;
use LWP::Simple;
#
my $verbose = 0;
#
my ($mday,$mon,$year) = (localtime (time - 24*60*60))[3,4,5];
my $startdate = sprintf("%02d/%02d/%04d", $mon+1, $mday, $year+1900);
my $enddate = $startdate;
my $period = 'daily';
#
my $outputdir = '';
my $inputfile = '';
#
my $plotline = '';
my $plotcandlesticks = '';
my $plotvolume = 0;
my $ylimits = '';
#
my $smoothingtypes = '';
my @smoothing = ();
#
our $expectation;
our %dists = ();
#
sub usage {
	print <<EOF;

usage: yahoo_quotes [-?V]
	[-o [directory|stdout]] [-i input file]
	[-p [all|open|high|low|close|adjclose] [-v]] [-P]
	[-c [close|adjclose]] [-C]
	[-y [low:hi | *:hi | low:* | *:*]]
	[-d|-w|-m]
	[-s [mm/dd/yyy|#|#d|#w|#m|#y]]
	[-e [mm/dd/yyy|#|#d|#w|#m|#y]] sym1 [sym2 [...]]
	[-S price:type[,price:type[,...]]]
	sym1 [sym2 [...]]

where:

	-i input file = datafile written by this script or with the same
		internal format.
	-o [directory|stdout] = output directory where data files are written.
	-p [all|open|high|low|close|adjclose] = plot lines for the
		given type of data. all is the default.
	-P = the same as '-p all'.
	-c [close|adjclose] = plot candlestick diagrams using open, low, high
		and close or adjusted close depending on what is requested.
	-C = the same as '-c close'.
	-y [low:hi | *:hi | low:* | *:*] = y-axis range limits where * means
		to automatically determine limits. auto low and hi is the default.
	-d|-w|-m = get daily or weekly or monthly quotes, the values are mutually
		exclusive. daily is the default.
	-s [mm/dd/yyy|#|#d|#w|#m|#y] = start date for getting data, or days, weeks,
		months, or years back. default is the previous day.
	-e [mm/dd/yyy|#|#d|#w|#m|#y] = end date for getting data, or days, weeks,
		months, or years back. default is the previous day.
	-S price[+price...]:type[,price[+price...]:type[,...]] = 
		where price is '+'-separated list of one ore more from the set:
		open, high, low, close, adjclose.  type is the type of smoothing to use. 
		the smoothing types are:
		ema:alpha=X:tick=Y - exponential moving average 
			with 0 < X < 1 or X > 1, and tick >= 0. tick = 0
			means there is NO rounding to the nearest tick
			multiple. tick > 0 means round to the nearest
			tick multiple. if X > 1, then alpha = 2/(X+1).
		sma:n=X:tick=Y - simple moving average where n > 0 is the
			number of measurements to average, and tick is the
			same as above.
		smm:n=X:tick=Y - simple moving median where n > 1 is the
			number of measurements to search for the median, and 
			tick is the same as above.
		wma:n=X:tick=Y - weighted moving average where n > 0 is the
			number of measurements to average, and tick is the
			same as above.
		cma:tick=Y - cumulative moving average (no parameters). 
			tick is the same as above.
		round:tick=Y - only round to nearest tick. tick is the same
			as above.
		conv:n=N:w1=X1,w2=X2,...,wN=XN:tick=Y - convolution of 
			N (must be odd) points using constant weights 
			W1, W2, ..., WN, and tick is the same as above.
		bb:mat[:alpha=A]:n=X:k=Y:tick=Z = bollinger bands where mat is the base moving
			average type, X is the number of days in the average,
			Y is the number of standard deviations for the upper and
			lower bands, and tick is described above. mat can be any of these:
			ema, sma, smm, wma, cma, or round. if mat = ema, then alpha 
			must be given and 0 < A < 1 or A > 1.  if A > 1, then 
			alpha = 2/(A+1).
	sym1, ... = retrieve data for these symbols.

EOF
}
#
my %bb_matypes = (
	"ema" => \&exponential_moving_average,
	"sma" => \&simple_moving_average,
	"smm" => \&simple_moving_median,
	"wma" => \&weighted_moving_average,
	"cma" => \&cumulative_moving_average,
	"round" => \&round_only,
);
#
sub copy {
	my ($psmoothed, $pdata) = @_;
	@{$psmoothed} =  @{$pdata};
}
#
sub bollinger_bands {
	my ($psmoothed, $pdata, $href) = @_;
	#
	my $matype = $href->{matype};
	my $n = $href->{n};
	my $k = $href->{k};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	die "$matype is unknown." unless (exists($bb_matypes{$matype}));
	#
	my @madata = ();
	$href->{tick} = 0;
	&{$bb_matypes{$matype}}(\@madata, $pdata, $href);
	$href->{tick} = $tick;
	#
	my $sum = 0;
	for (my $i=0; $i<$n; $i++) {
		my $diff = $pdata->[$i] - $madata[$n-1];
		$sum += $diff * $diff;
	}
	my $sd2 = $sum/$n;
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	# backfill using what we have
	for (my $i=0; $i<$n; $i++) {
		$psmoothed->[$i] = &{${rounding}}($madata[$i]+$k*sqrt($sd2), $tick);
	}
	#
	for (my $i=$n; $i<$nd; $i++) {
		my $sum = 0;
		for (my $j=0; $j<$n; $j++) {
			my $diff = $pdata->[$i-$j] - $madata[$i];
			$sum += $diff * $diff;
		}
		my $sd2 = $sum/$n;
		$psmoothed->[$i] = &{${rounding}}($madata[$i]+$k*sqrt($sd2), $tick);
	}
	#
	return;
}
#
sub exponential_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	my $alpha = $href->{alpha};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $ema = $pdata->[0];
	$psmoothed->[0] = &{${rounding}}($ema, $tick);
	for (my $i=1; $i<$nd; $i++) {
		$ema = $alpha*$pdata->[$i] + (1.0-$alpha)*$ema;
		$psmoothed->[$i] = &{${rounding}}($ema, $tick);
	}
	#
	return;
}
#
sub simple_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	copy($psmoothed, $pdata);
	#
	my $n = $href->{n};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	return if ($nd <= $n);
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $sum = 0;
	for (my $i=0; $i<$n; $i++) {
		$sum += $pdata->[$i];
	}
	my $sma = $sum/$n;
	#
	$psmoothed->[$n-1] = &{${rounding}}($sma, $tick);
	for (my $i=$n; $i<$nd; $i++) {
		$sma = $sma - $pdata->[$i-$n]/$n + $pdata->[$i]/$n;
		$psmoothed->[$i] = &{${rounding}}($sma, $tick);
	}
	#
	return;
}
#
sub simple_moving_median {
	my ($psmoothed, $pdata, $href) = @_;
	#
	copy($psmoothed, $pdata);
	#
	my $n = $href->{n};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	return if ($nd <= $n);
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	for (my $i=$n; $i<$nd; $i++) {
		my @unsorted = @{$pdata}[($i-$n) .. ($i-1)];
		my @sorted = sort { $a <=> $b } @unsorted;
		my $smm = $sorted[int($n/2+0.5)];
		$psmoothed->[$i] = &{${rounding}}($smm, $tick);
	}
	#
	return;
}
#
sub weighted_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	copy($psmoothed, $pdata);
	#
	my $n = $href->{n};
	my $tick = $href->{tick};
	my $divisor = $href->{divisor};
	my $nd = scalar @{$pdata};
	#
	return if ($nd <= $n);
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $total = 0;
	my $numerator = 0;
	for (my $i=0; $i<$n; $i++) {
		$total += $pdata->[$i];
		$numerator += ($i+1)*$pdata->[$i];
	}
	my $wma = $numerator/$divisor;
	#
	$psmoothed->[$n-1] = &{${rounding}}($wma, $tick);
	for (my $i=$n; $i<$nd; $i++) {
		$total = $total - $pdata->[$i-$n] + $pdata->[$i];
		$numerator = $numerator + $n*$pdata->[$i] - $total;
		$wma = $numerator/$divisor;
		$psmoothed->[$i] = &{${rounding}}($wma, $tick);
	}
	#
	return;
}
#
sub cumulative_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $cma = $pdata->[0];
	$psmoothed->[0] = &{${rounding}}($cma, $tick);
	for (my $i=1; $i<$nd; $i++) {
		$cma = $cma + ($pdata->[$i] - $cma)/($i+1);
		$psmoothed->[$i] = &{${rounding}}($cma, $tick);
	}
	#
	return;
}
#
sub round_only {
	my ($psmoothed, $pdata, $href) = @_;
	#
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	for (my $i=0; $i<$nd; $i++) {
		$psmoothed->[$i] = &{${rounding}}($pdata->[$i], $tick);
	}
	return;
}
#
sub naive_convolution {
	my ($psmoothed, $pdata, $href) = @_;
	copy($psmoothed, $pdata);
	return;
}
#
sub combineprices {
	my ($pcombinedprices, $pallprices, $ndata, $pricestr) = @_;
	#
	for (my $i=0; $i<$ndata; $i++) {
		$pcombinedprices->[$i] = 0;
	}
	#
	my @prices = split(/\+/, $pricestr);
	my $nprices = scalar @prices;
	foreach my $price (@prices) {
		my $pdata = $pallprices->{$price};
		for (my $i=0; $i<$ndata; $i++) {
			$pcombinedprices->[$i] += $pdata->[$i]/$nprices;
		}
	}
}
#
sub generateplotsmoothcmd {
	my ($symbol, $data) = @_;
	#
	return "" unless ($smoothingtypes ne '');
	#
	my $tmpfile = "/tmp/smoothed.${symbol}.dat.$$";
	print "TMP Smooothed Data File: $tmpfile\n";
	open(TMPFILE, ">${tmpfile}") or die "unable to open output file ${tmpfile}: $!";
	#
	my @quotes = split(/\n/, $data);
	#
	# Date,Open,High,Low,Close,Volume,Adj Close
	my %allprices;
	$allprices{date} = ();
	$allprices{open} = ();
	$allprices{high} = ();
	$allprices{low} = ();
	$allprices{close} = ();
	$allprices{volume} = ();
	$allprices{adjclose} = ();
	#
	foreach my $prices (@quotes) {
		print "PRICES: $prices \n" if ($verbose);
		my (@onedayprices) = split(/,/, $prices);
		push @{$allprices{date}}, $onedayprices[0];
		push @{$allprices{open}}, $onedayprices[1];
		push @{$allprices{high}}, $onedayprices[2];
		push @{$allprices{low}}, $onedayprices[3];
		push @{$allprices{close}}, $onedayprices[4];
		push @{$allprices{volume}}, $onedayprices[5];
		push @{$allprices{adjclose}}, $onedayprices[6];
	}
	#
	my $plotcmd = "";
	my $datai = 0;
	foreach my $href (@smoothing) {
		my $func = $href->{function};
		my $name = $href->{name};
		my $price = $href->{price};
		#
		my @combinedprices = ();
		combineprices(\@combinedprices, \%allprices, scalar @{$allprices{date}}, $price);
		#
		my @smoothedprice = ();
		&{${func}}(\@{smoothedprice}, \@combinedprices, $href);
		#
		for (my $i=0; $i<scalar @{$allprices{date}}; $i++) {
			print TMPFILE $allprices{date}->[$i] . "," . $smoothedprice[$i] . "\n";
		}
		print TMPFILE "\n\n";
		$plotcmd .= ",'${tmpfile}' using 1:2 index ${datai} title \"${name} smoothed ${price}\" with lines";
		$datai += 1;
	}
	close(TMPFILE);
	#
	return "$plotcmd";
}
#
sub plotdata {
	my ($symbol, $data) = @_;
	#
	my $tmpfile = "/tmp/${symbol}.dat.$$";
	print "TMP Data File: $tmpfile\n";
	open(TMPFILE, ">${tmpfile}") or 
		die "unable to open output file ${tmpfile}: $!";
	#
	my @quotes = split(/\n/, $data);
	splice(@quotes, 0, 1);
	$data = join("\n", @quotes);
	print TMPFILE $data . "\n";
	close(TMPFILE); 
	#
	my $plotsmoothcmd  = generateplotsmoothcmd($symbol, $data);
	#
	my $plotinitcmd = 'set term x11;';
	$plotinitcmd .= 'set xdata time;';
	$plotinitcmd .= 'set timefmt "%Y-%m-%d";';
	$plotinitcmd .= 'set datafile separator ",";';
	$plotinitcmd .= "set yrange [${ylimits}];" if ($ylimits ne '');
	$plotinitcmd .= 'set xlabel "Date: YY/MM/DD";';
	$plotinitcmd .= 'set ylabel "Price: $";';
	$plotinitcmd .= "set title 'Data for ${symbol}';";
	$plotinitcmd .= 'set multiplot;';
	#
	if ($plotline ne '') {
		open (GP, "|/usr/bin/gnuplot -persist") or die "no gnuplot";
		GP->autoflush(1);
		#
		my $plotcmd = $plotinitcmd;
		$plotcmd .= "plot ";
		my $comma = '';
		foreach my $field (split(',', $plotline)) {
			if ($field eq 'open') {
				$plotcmd .= "${comma}'${tmpfile}' using 1:2 index 0 title \"open\" with lines";
			} elsif ($field eq 'high') {
				$plotcmd .= "${comma}'${tmpfile}' using 1:3 index 0 title \"high\" with lines";
			} elsif ($field eq 'low') {
				$plotcmd .= "${comma}'${tmpfile}' using 1:4 index 0 title \"low\" with lines";
			} elsif ($field eq 'close') {
				$plotcmd .= "${comma}'${tmpfile}' using 1:5 index 0 title \"close\" with lines";
			} elsif ($field eq 'adjclose') {
				$plotcmd .= "${comma}'${tmpfile}' using 1:7 index 0 title \"adjclose\" with lines";
			} else {
				$plotcmd .= "${comma}'${tmpfile}' using 1:2 index 0 title \"open\" with lines";
				$comma = ',';
				$plotcmd .= "${comma}'${tmpfile}' using 1:3 index 0 title \"high\" with lines";
				$plotcmd .= "${comma}'${tmpfile}' using 1:4 index 0 title \"low\" with lines";
				$plotcmd .= "${comma}'${tmpfile}' using 1:5 index 0 title \"close\" with lines";
				$plotcmd .= "${comma}'${tmpfile}' using 1:7 index 0 title \"adjclose\" with lines";
			}
			$comma = ',';
		}
		print GP $plotcmd;
		print GP $plotsmoothcmd if ($plotsmoothcmd ne '');
		print GP "\n";
		close GP;
		#
		if ($plotvolume) {
			open (GP, "|/usr/bin/gnuplot -persist") or die "no gnuplot";
			GP->autoflush(1);
			my $plotcmd = $plotinitcmd;
			$plotcmd .= "plot ";
			$plotcmd .= "'${tmpfile}' using 1:6 index 0 title \"volume\" with lines;";
			print GP $plotcmd . "\n";
			close GP;
		}
	}
	#
	if ($plotcandlesticks ne '') {
		open (GP, "|/usr/bin/gnuplot -persist") or die "no gnuplot";
		GP->autoflush(1);
		#
		my $plotcmd = $plotinitcmd;
		$plotcmd .= "plot ";
		foreach my $field (split(',', $plotcandlesticks)) {
			if ($field eq 'adjclose') {
				$plotcmd .= "'${tmpfile}' using 1:2:4:3:7 index 0 title \"adjclose\" with candlesticks";
			} else {
				$plotcmd .= "'${tmpfile}' using 1:2:4:3:7 index 0 title \"close\" with candlesticks";
			}
		}
		print GP $plotcmd;
		print GP $plotsmoothcmd if ($plotsmoothcmd ne '');
		print GP "\n";
		close GP;
	}
	return;
}
#
sub writedata {
	my ($symbol, $data) = @_;
	#
	if ("$outputdir" ne "stdout") {
		my $outfile = "${outputdir}/${symbol}.csv";
		print "${symbol} Data Output File: ${outfile}\n";
		#
		open(OUTFILE, ">${outfile}") or
			die "unable to open output file ${outfile}: $!";
		print OUTFILE $data;
		close(OUTFILE); 
	} else {
		print "\nDATA: " . $data . "\n";
	}
	#
	return;
}
#
sub normalize {
	my ($pdata) = @_;
	my @quotes = split(/\n/, $$pdata);
	my $header = $quotes[0];
	splice(@quotes, 0, 1);
	@quotes = reverse(@quotes);
	$$pdata = $header . "\n" . join("\n", @quotes);
}
#
sub queryyahoo {
	my ($symbol, $url) = @_;
	#
	print "Yahoo Query For ${symbol}: ${url}\n" if ($verbose);
	#
	my $content;
	for (my $i=1; $i<=5; $i++) {
		$content = get $url;
		last if (defined $content);
		print "Sleep and retry ...\n";
		sleep 1;
	}
	#
	if (defined ${content}) {
		normalize(\$content);
		if ($outputdir ne '') {
			writedata($symbol, $content);
		} elsif ($plotline ne '' or $plotcandlesticks ne '') {
			plotdata($symbol, $content);
		} else {
			print "${content}";
		}
	} else {
		print "NO DATA FOR ${symbol}\n";
	}
	#
	return;
}
#
sub symboldata {
	my ($symbol) = @_;
	#
	$symbol =~ tr/a-z/A-Z/;
	print "\nProcessing Symbol: $symbol \n";
	#
	my ($smon,$sday,$syear) = split(/\//, $startdate);
	my ($emon,$eday,$eyear) = split(/\//, $enddate);
	my $query = "http://ichart.finance.yahoo.com/table.csv?";
	#
	$sday += 0;
	$eday += 0;
	$smon = sprintf("%02d", $smon-1);
	$emon = sprintf("%02d", $emon-1);
	#
	$query .= "s=${symbol}";
	$query .= "&a=${smon}&b=${sday}&c=${syear}";
	$query .= "&d=${emon}&e=${eday}&f=${eyear}";
	#
	if ($period eq "weekly") {
		$query .= "&g=w";
	} elsif ($period eq "monthly") {
		$query .= "&g=m";
	} else {
		# daily is default
		$query .= "&g=d";
	}
	#
	queryyahoo($symbol, $query);
	#
	return;
}
#
sub readinputfile {
	my ($infile) = @_;
	#
	open(INFILE, "<${infile}") or 
		die "unable to open input file ${infile}: $!";
	my (@quotes) = <INFILE>;
	my $content = join("", @quotes);
	close(INFILE); 
	#
	if ($plotline ne '' or $plotcandlesticks ne '') {
		plotdata(basename($infile), $content);
	} else {
		print "${content}";
	}
	return;
}
#
sub formatdate {
	my ($type, $date) = @_;
	if ($date =~ m?^[0-9][0-9]/[0-9][0-9]/[0-9]{4}?) {
		return $date;
	} elsif ($date =~ m/^([0-9]+)([dDwWmMyY]){0,1}$/) {
		my $number = ${1};
		my $type = ${2};
		if (defined($type)) {
			$type =~ tr/a-z/A-Z/;
			if ($type eq 'W') {
				$number *= 7;
			} elsif ($type eq 'M') {
				$number *= 30;
			} elsif ($type eq 'Y') {
				$number *= 365;
			}
		}
		my ($mday,$mon,$year) = 
			(localtime(time-$number*24*60*60))[3,4,5];
		return sprintf("%02d/%02d/%04d", $mon+1, $mday, $year+1900);
	} else {
		die "bad ${type} date format";
		return "";
	}
}
#
sub initsmoothing {
	my ($smoothingtypes) = @_;
	#
	return unless ($smoothingtypes ne '');
	#
	foreach my $smoothingtype (split(/,/, $smoothingtypes)) {
		if ($smoothingtype =~ m/^([^:]+):ema:alpha=([\.0-9]+):tick=([\.0-9]+)/) {
			my $alpha = ${2};
			if ($alpha > 1.0) {
				$alpha = 2/($alpha+1);
			}
			push @smoothing, {
				function => \&exponential_moving_average,
				name => 'exponential_moving_average',
				price => ${1},
				alpha => ${alpha},
				tick => ${3}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):bb:ema:alpha=([\.0-9]+):n=([0-9]+):k=([\.0-9]+):tick=([\.0-9]+)/) {
			# bb:ema[:alpha=A]:n=X:k=Y:tick=Z = bollinger bands where mma is the base moving
			my $alpha = ${2};
			if ($alpha > 1.0) {
				$alpha = 2/($alpha+1);
			}
			my $k = ${4};
			push @smoothing, {
				function => \&bollinger_bands,
				name => 'bollinger_bands',
				price => ${1},
				matype => 'ema',
				alpha => ${alpha},
				n => ${3},
				k => ${k},
				tick => ${5}
			};
			#
			push @smoothing, {
				function => \&exponential_moving_average,
				name => 'bollinger bands moving average - ema',
				price => ${1},
				alpha => ${alpha},
				tick => ${5}
			};
			#
			$k *= -1;
			push @smoothing, {
				function => \&bollinger_bands,
				name => 'bollinger_bands',
				price => ${1},
				matype => 'ema',
				alpha => ${alpha},
				n => ${3},
				k => ${k},
				tick => ${5}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):bb:([a-z]+):n=([0-9]+):k=([\.0-9]+):tick=([\.0-9]+)/) {
			# bb:ma:n=X:k=Y:tick=Z = bollinger bands where mma is the base moving
			my $divisor = ${3}*(${3}+1);
			$divisor = ($divisor-($divisor%2))/2;
			my $k = ${4};
			push @smoothing, {
				function => \&bollinger_bands,
				name => 'bollinger_bands',
				price => ${1},
				matype => ${2},
				n => ${3},
				k => ${k},
				divisor => ${divisor},
				tick => ${5}
			};
			#
			die "${2} is unknown." unless (exists($bb_matypes{${2}}));
			#
			push @smoothing, {
				function => $bb_matypes{$2},
				name => "bollinger bands moving average - ${2}",
				price => ${1},
				divisor => ${divisor},
				n => ${3},
				tick => ${5}
			};
			#
			$k *= -1;
			push @smoothing, {
				function => \&bollinger_bands,
				name => 'bollinger_bands',
				price => ${1},
				matype => ${2},
				n => ${3},
				k => ${k},
				divisor => ${divisor},
				tick => ${5}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):sma:n=([0-9]+):tick=([\.0-9]+)/) {
			push @smoothing, {
				function => \&simple_moving_average,
				name => 'simple_moving_average',
				price => ${1},
				n => ${2},
				tick => ${3}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):smm:n=([0-9]+):tick=([\.0-9]+)/) {
			push @smoothing, {
				function => \&simple_moving_median,
				name => 'simple_moving_median',
				price => ${1},
				n => ${2},
				tick => ${3}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):wma:n=([0-9]+):tick=([\.0-9]+)/) {
			my $divisor = ${2}*(${2}+1);
			$divisor = ($divisor-($divisor%2))/2;
			push @smoothing, {
				function => \&weighted_moving_average,
				name => 'weighted_moving_average',
				price => ${1},
				n => ${2},
				divisor => ${divisor},
				tick => ${3}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):cma:tick=([\.0-9]+)/) {
			push @smoothing, {
				function => \&cumulative_moving_average,
				name => 'cumulative_moving_average',
				price => ${1},
				tick => ${2}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):round:tick=([\.0-9]+)/) {
			push @smoothing, {
				function => \&round_only,
				name => 'round_only',
				price => ${1},
				tick => ${2}
			};
		} elsif ($smoothingtype =~ m/^([^:]+):conv:n=([0-9]+):((w[0-9]+=[\.0-9\-]+|:)+):tick=([\.0-9]+)/) {
			my %data = ();
			$data{function} = \&naive_convolution;
			$data{name} = 'naive_convolution';
			$data{price} = ${1};
			$data{n} = ${2};
			my $weights = ${3};
			$data{tick} = ${5};
			my $n = $data{n};
			my $total = 0;
			for (my $i=1; $i<=$n; ${i}++) {
				my $weight = ($weights =~ m/w${i}=([\.0-9]+)/) ? ${2} : 0.0;
				$data{weights}->[${i}-1] = $weight;
				$total += $weight;
			}
			$total = abs($total);
			${total} = 1.0 if ($total == 0);
			$data{normalizer} = ${total};
			for (my $i=0; $i<$n; ${i}++) {
				printf "W[%d] = %f\n", $i+1, $data{weights}->[${i}];
			}
			push @smoothing, \%data;
		} else {
			die "Unknown filtering option or wrong format: $smoothingtype";
		}
	}
	#
	print "\nSmoothing Parameters: \n\n";
	for my $href ( @smoothing ) {
    		print "{ ";
    		for my $param ( keys %$href ) {
			if (defined($href->{$param})) {
         			print "$param=$href->{$param} ";
			} else {
         			print "$param=Does NOT Exist ";
			}
    		}
    		print "}\n";
	}
	#
	return;
}
#
my %opts;
if (getopts('?CPi:S:y:Vp:c:vs:e:o:dwm', \%opts) != 1) {
	usage();
	exit 2;
}
#
foreach my $opt (%opts) {
	if ($opt eq "?") {
		usage();
		exit 0;
	} elsif ($opt eq "V") {
		$verbose = 1;
	} elsif ($opt eq "P") {
		$plotline = 'all';
	} elsif ($opt eq "p") {
		$plotline = $opts{$opt};
	} elsif ($opt eq "i") {
		$inputfile = $opts{$opt};
	} elsif ($opt eq "y") {
		$ylimits = $opts{$opt};
	} elsif ($opt eq "C") {
		$plotcandlesticks = 'close';
	} elsif ($opt eq "c") {
		$plotcandlesticks = $opts{$opt};
	} elsif ($opt eq "v") {
		$plotvolume = 1;
	} elsif ($opt eq "o") {
		$outputdir = $opts{$opt};
	} elsif ($opt eq "S") {
		$smoothingtypes = $opts{$opt};
	} elsif ($opt eq "s") {
		$startdate = formatdate('start', $opts{$opt});
	} elsif ($opt eq "e") {
		$enddate = formatdate('end', $opts{$opt});
	} elsif ($opt eq "d") {
		$period = "daily";
	} elsif ($opt eq "w") {
		$period = "weekly";
	} elsif ($opt eq "m") {
		$period = "monthly";
	}
}
#
initsmoothing($smoothingtypes);
#
if ($inputfile ne '') {
	readinputfile($inputfile);
} else {
	if (scalar(@ARGV) == 0) {
		print "\nNo symbols given.\n";
		usage();
		exit 2;
	}
	#
	print "\n";
	print "Start Date: ${startdate}\n";
	print "End   Date: ${enddate}\n";
	#
	foreach my $symbol (@ARGV) {
		symboldata($symbol);
	}
}
#
exit 0;
