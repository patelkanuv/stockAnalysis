#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw (tv_interval gettimeofday);
use Try::Tiny;
use Text::CSV::Simple;
use Getopt::Long;

#filter values, 
#negative value means less than or equal to
#positive value means greater than or equal to

my ($name, $cap, $pb, $pe, $margin, $one_year, $three_year, $five_year, $ten_year); 

GetOptions ( "name=s"   => \$name,    # numeric
             "cap=s"    => \$cap,     # string
             "pe=i"     => \$pe,
             "pb=i"     => \$pb,
             "margin=i" => \$margin,
             "1Y=i"     => \$one_year,
             "3Y=i"     => \$three_year,
             "5Y=i"     => \$five_year,
             "10Y=i"     => \$ten_year)     # 
           or die("Error in command line arguments\n");

my @stock_records       = read_records_file();
my @cagr_records        = read_cagr_recors();
my @filtered_results    = filter_records(@stock_records);

print_records(@filtered_results);

sub read_records_file {
    my $parser1 = Text::CSV::Simple->new();
    $parser1->field_map(qw/Name Code industry MyView price change change_perc volume PE 
                          PB Cap Revenue Profit NetMargin ROE 1M 3M 1Y 3Y 5Y 10Y/);
    my @data    = $parser1->read_file("Reports/stock_report.csv");
       
    return @data;    
}

sub read_cagr_recors {
    my $parser2     = Text::CSV::Simple->new();
    $parser2->field_map(qw/ Name code myView DebtToEqity CurrentRatio CAGR_1 CAGR_2 CAGR_3 CAGR_4 CAGR_5 CAGR_6 /);
    my @data_cagr   = $parser2->read_file("Reports/stock_cagr_report.csv");
    
    return @data_cagr;
}

sub get_cagr_record {
    my ($code)    = @_;
    #print $code, "\n";
    foreach my $rec (@cagr_records) {
        if($rec->{code} eq $code) {
            return $rec;
        }    
    }
    
    return {};
}

sub filter_records {
    my (@records) = @_;
    
    @records    = name_filter($name, @records) if defined $name;
    @records    = cap_filter($cap, @records) if defined $cap;
    @records    = pe_filter($pe, @records) if defined $pe;
    @records    = pb_filter($pb, @records) if defined $pb;
    @records    = margin_filter($margin, @records) if defined $margin;
    @records    = year_filter($one_year, '1Y', @records) if defined $one_year;
    @records    = year_filter($three_year, '3Y', @records) if defined $three_year;
    @records    = year_filter($five_year, '5Y', @records) if defined $five_year;
    @records    = year_filter($ten_year, '10Y', @records) if defined $ten_year;
    
    return @records;    
}

sub name_filter {
    my ($name, @records)    = @_;
    
    my @filtered_records;
    
    foreach my $rec (@records) {
        $rec->{Name} =~ s/^\s+|\s+$//g;
        if($rec->{Name} =~ /$name/gxi) {
            push(@filtered_records, $rec);
        }    
    }
    return @filtered_records; 
}

sub cap_filter {
    my ($cap, @records)    = @_;
    
    my @filtered_records;
    
    foreach my $rec (@records) {
        my $c_name = 'S';
        my $m_cap   = decommify($rec->{Cap});
        if( $m_cap >= 20000) {
            $c_name = 'L';
        }
        elsif ($m_cap  >= 5000 && $m_cap  <= 20000) {
            $c_name = 'M';
        }
        
        if($c_name =~ /$cap/gx) {
            push(@filtered_records, $rec);
        }    
    }
    return @filtered_records; 
}

sub pb_filter {
    my ($pb, @records)    = @_;
    
    return master_filter($pb, 'PB', @records); 
}

sub pe_filter {
    my ($pe, @records)    = @_;
    
    return master_filter($pe, 'PE', @records);
}

sub margin_filter {
    my ($margin, @records)    = @_;
    
    return master_filter($margin, 'NetMargin', @records);
}

sub year_filter {
    my ($year, $year_key, @records)    = @_;
    
    return master_filter($year, $year_key, @records);
}

sub master_filter {
    my($filter_value, $filter_key, @records) = @_;
    
    my @filtered_records;    
    
    if($filter_value < 0) {
        foreach my $rec (@records) {
            my $rec_value   = decommify($rec->{$filter_key});
            if($rec_value <= abs($filter_value) ) {
                push(@filtered_records, $rec);
            }
        }
    }
    else { 
        foreach my $rec (@records) {
            my $rec_value   = decommify($rec->{$filter_key});       
            if($rec_value >= $filter_value ) {
                push(@filtered_records, $rec);
            }    
        }
    }
    
    return @filtered_records;
}

sub print_records {
    my (@records) = @_;
    
    my $header1  = sprintf ("\n%-20s %-10s %10s %9s %12s %7s %9s %9s %7s %7s %7s %5s\n", 
                  "Name", 'MyOpinion', 'Price  ', 'Change ',  'Volume ', '  PE ',  
                  'Margin ', "current", "1Y  ", "3Y  ", "5Y  ", "10Y");
    my $header2  = sprintf ("%-20s %-10s %10s %7s %12s %8s %10s %9s %7s %7s %7s %7s %7s %7s\n", 
                  "Industry", 'MyOpinion', ' ', 'Ch %', 'M-Cap', '  PB', "ROE ", ' Eq-Debt', 
                  "CAGR1", "CAGR2", "CAGR3", "CAGR4", "CAGR5", "CAGR6");
    print $header1;
    print $header2;
    
    print("-" x 140, "\n");
    if(scalar(@records) == 0) {
        print "No record matches your search\n\n\n";
        return;
    }
    foreach my $rec (@records) {
        next if ($rec->{Name} eq 'Name');
        my $cagr_rec        = get_cagr_record($rec->{Code});
        my $record_line1    = sprintf ("%-20s %7s %3s %10s %9s %12s %7s %8s %8s %7s %7s %7s %7s\n", 
            substr($rec->{Name},0,20),
            $rec->{MyView},
            ' ',
            $rec->{price},
            $rec->{change},
            $rec->{volume},
            $rec->{PE},
            $rec->{NetMargin},
            $cagr_rec->{CurrentRatio},
            $rec->{'1Y'},
            $rec->{'3Y'},
            $rec->{'5Y'},
            $rec->{'10Y'}
        );
                        
        my $record_line2    = sprintf ("%-20s %7s %16s %5.2f%1s %13s %7s %8s %8s %7s %7s %7s %7s %7s %7s\n", 
            substr($rec->{industry},0,20),
            $cagr_rec->{myView},
            ' ',
            decommify($rec->{change_perc}),
            '%',
            $rec->{Cap},
            $rec->{PB},
            $rec->{ROE},
            $cagr_rec->{DebtToEqity},
            $cagr_rec->{CAGR_1},
            $cagr_rec->{CAGR_2},
            $cagr_rec->{CAGR_3},
            $cagr_rec->{CAGR_4},
            $cagr_rec->{CAGR_5},
            $cagr_rec->{CAGR_6},
        );
        print $record_line1;
        print $record_line2;
        print("-" x 140, "\n");
    }
}

sub decommify { 
    my ( $number ) = @_;
    $number =~ tr/,|%//d;
  return $number
}
