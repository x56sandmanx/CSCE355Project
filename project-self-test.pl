#!/usr/bin/perl -w

# Perl script for testing a CSCE 355 project submission on a linux lab box

# Usage:
# $ project-test.pl [your-submission-root-directory]
#
# The directory argument is optional.  If not there, then the default is
# $default_submission_root, defined below.

# PLEASE NOTE: This script normally (over)writes the file "comments.txt"
# in your submission root directory.  If that already exists, the existing
# file is first changed to "comments.bak".  The script also (over)writes
# "errlog.txt" in your submission root directory.

# This script must be run under the bash shell.


######## Edit the following to reflect your directory structure (mandatory):

# directory containing all the test files
# (edit this for self-testing; when we grade, it will point to our version)
$test_files_root = "test";

########### Editing below this line is optional. #############

# IMPORTANT: You may change these variables below for your own testing
# purposes, but your program will be graded using the current values
# of these variables.

# Edit to point to your submission root directory, i.e., the directory
# containing your "build-run.txt" file, if you don't want to specify it
# on the command line every time.
# (This variable will not be used in grading.)
$default_submission_root = ".";

# This is the subdirectory (relative to your submission root directory)
# where the script temporarily stores the results of running your code.
# Change this if you want them placed somewhere else.  You should NOT
# set this to be the same as your test directory; otherwise it will clobber
# the files used to compare with your outputs!
$test_outputs = "test-outputs";

# Flag to control deletion of temporary files --
# a nonzero value means all temp files are deleted after they are used;
# a zero value means no temp files will be deleted (but they will be
# overwritten on subsequent executions of this script).
# This flag has NO effect on files created by running your program if
# it times out (that is, exceeds the $timeout limit, below); those files will
# always be deleted.
# Set this value to 0 if you want to examine your own program's outputs as
# produced by this script.

# The linux diff command is run to compare your output with that of the
# solution.  If there is a discrepancy, the first 16 lines of the diff
# output are displayed.  Change this variable to change the number of initial
# lines of diff output to display.  (diff output is piped through the linux
# 'head' command; see $diff_pipe, below.)
$num_diff_lines = 16;
# If the 'head' command is different on your platform, alter the following
# variable accordingly.  If you want the whole unpiped diff output, set this
# variable to the empty string.
$diff_pipe = "| head --lines=$num_diff_lines";

# Set to 0 by default.  -SF 4/23/2021 @ 12:30pm
$delete_temps = 0;

# Time limit for each run of your program (in seconds).  This is the value
# I will use when grading, but if you want to allow more time in the testing
# phase, increase this value.
$timeout = 11;     # seconds


############# You should not need to edit below this line. ###############

# Keys are tasks attempted;
# values are the corresponding point values.
%progress = ();

# Holds build and run commands for the program
%build_run = ();

# Base names for the test files
@test_bases = ('add','bin2un','compare','copy','sample','tag_system');

# Check existence and readability of the test files directory
die "Test files directory $test_files_root\n  does not exist or is inaccessible\n"
    unless -d $test_files_root && -r $test_files_root;

#sub main
{
    if (@ARGV) {
	$udir = shift @ARGV;
	$udir =~ s/\/$//;   # strip the trailing "/" if it is there
	$udir ne "" or die "Cannot use root directory\n";
    }
    else {
	$udir = $default_submission_root;
    }
#    $utils = "$udir/$utils";
    $uname = "self-test";
    process_user();
}


sub process_user {
    print "Processing user $uname\n";

    die "No accessible directory $udir ($!)\n"
	unless -d $udir && -r $udir && -w $udir && -x $udir;

    die "Cannot change to directory $udir ($!)\n"
	unless chdir $udir;

    print "Current working directory is $udir\n";

    # Copy STDOUT and STDERR to errlog.txt in $udir
    open STDOUT, "| tee errlog.txt" or die "Can't redirect stdout\n";
    open STDERR, ">&STDOUT" or die "Can't dup stdout\n";
    select STDERR; $| = 1;	# make unbuffered
    select STDOUT; $| = 1;	# make unbuffered

    if (-e "comments.txt") {
	print "comments.txt exists -- making backup comments.bak\n";
	rename "comments.txt", "comments.bak";
    }

    open(COMMENTS, "> comments.txt");

    cmt("Comments for $uname -------- " . now() . "\n");
    cmt("Current working directory is $udir\n");

    mkdir $test_outputs
	unless -d $test_outputs;

    cmt("parsing the build-run.txt file ...");
    if (parse_build_run()) {
	cmt("ERROR PARSING build-run.txt ... quitting\n");
	exit(1);
    }
    cmt(" done\n\n");
    cmt("building executable ...\n");
    $rc = 0;
    foreach $command (@{$build_run{BUILD}}) {
	if ($command =~ /\s*make(\s|$)/ && $command !~ /-B/) {
	    cmt("    Changing command \"$command\" to ");
	    $command =~ s/\s*make/make -B/;
	    cmt(" \"$command\"\n");
	}
	else {
	    cmt("  $command\n");
	}
	$rc = system($command);    # attempt the next build command
	if ($rc >> 8) {
	    cmt("    FAILED ... quitting\n");
	    exit(1);
	}
	cmt("    succeeded\n");
    }
    $base_command = $build_run{RUN};
    cmt(" done\n    base command is \"$base_command\"\n\n");

    foreach $arg (@test_bases) {
	test_task($arg);
    }

    rmdir $test_outputs if $delete_temps;
    cmt("done\n\n");

    report_summary();

    close COMMENTS;

    print "\nDone.\nComments are in $udir/comments.txt\n\n";
}

# Do a single run of the program
sub test_task {
    my ($arg) = @_;

    cmt("testing $arg ...\n");

    my $command;
    $command = "$base_command $test_files_root/TM_$arg.txt < $test_files_root/input_$arg.txt > $test_outputs/output_$arg.txt 2> $test_outputs/error_$arg.txt";
    $progress{$arg} = 1;

    cmt("  Running the command:\n  $command\n");
    eval {
	local $SIG{ALRM} = sub { die "TIMED OUT\n" };
	alarm $timeout;
	$rc = system($command);
	alarm 0;
    };
    if ($@ && $@ eq "TIMED OUT\n") {
	cmt("    $@");		# program timed out before finishing
	unlink "$test_outputs/output_$arg.txt"
	    if -e "$test_outputs/output_$arg.txt";
	unlink "$test_outputs/error_$arg.txt"
	    if -e "$test_outputs/error_$arg.txt";
	$progress{$arg} = 0;
    }
    if ($rc >> 8) {
	cmt("    (terminated with nonzero status (ignored))\n");
    }
    else {
	cmt("    (terminated with zero status (ignored))\n");
    }
    error_report($arg);

    if (!(-e "$test_outputs/output_$arg.txt")) {
	cmt("  OUTPUT FILE $test_outputs/output_$arg.txt DOES NOT EXIST\n");
	$progress{$arg} = 0;
    }

    cmt("  $test_outputs/output_$arg.txt exists---comparing with solution\n");

    $report = check_outcomes($arg);
    unlink "$test_outputs/output_$arg.txt" if $delete_temps;
    chomp $report;
    if ($report eq '') {
	cmt("  outcomes match (correct)\n\n");
    }
    else {
	cmt("  OUTCOMES DIFFER:\nv v v v v\n$report\n^ ^ ^ ^ ^\n\n");
	$progress{$arg} = 0;
    }
}


# Sets build_run hash to the building and execution commands for this program
# Returns nonzero if error
sub parse_build_run {
    $br_file = "build-run.txt";
    open BR, "< $br_file"
	or die "Cannot open $br_file for reading ($!)\n";
    get_line(1) or return 1;
    $line = eat_comments();
    if ($line !~ /^\s*Build:\s*$/i) {
	cmt("NO Build SECTION FOUND; ABORTING PARSE\n");
	return 1;
    }
    get_line(1) or return 1;
    $line = eat_comments();
    $build_run{BUILD} = [];
    while ($line ne "" && $line !~ /^\s*Run:\s*$/i) {
	$line =~ s/^\s*//;
	push @{$build_run{BUILD}}, $line;
	get_line(1) or return 1;
	$line = eat_comments();
    }
    if ($line eq "") {
	cmt("NO Run SECTION FOUND; ABORTING PARSE\n");
	return 1;
    }
    # This is now true: $line =~ /^\s*Run:\s*$/i
    get_line(1) or return 1;
    $line = eat_comments();
    $line =~ s/^\s*//;
    $build_run{RUN} = $line;
    get_line(0) or return 0;
    $line = eat_comments();
    if ($line ne "") {
	cmt("EXTRA TEXT IN FILE; ABORTING PARSE\n");
	return 1;
    }
    close BR;
    return 0;
}


sub get_line {
    my ($flag) = @_;
    return 1
	if defined($line = <BR>);
    if ($flag) {
	cmt(" FILE ENDED PREMATURELY\n");
    }
    return 0;
}


# Swallow comments and blank lines
sub eat_comments {
    chomp $line;
    while ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
	$line = <BR>;
	defined($line) or return "";
	chomp $line;
    }
    return $line
}


sub check_outcomes {
    my ($base) = @_;
    my $diff;

    cmt("Running \"diff\" on your output and the solution:\n");
    $diff = `diff $test_outputs/output_$base.txt $test_files_root/output_$base.txt $diff_pipe`;
    return $diff;
}


sub error_report {
    my ($base) = @_;
    if (-e "$test_outputs/error_$base.txt") {
	if (-s "$test_outputs/error_$base.txt") {
	    cmt("  standard error output:\nvvvvv\n");
	    $report = `cat $test_outputs/error_$base.txt`;
	    chomp $report;
	    cmt("$report\n^^^^^\n");
	}
	unlink "$test_outputs/error_$base.txt" if $delete_temps;
    }
}


sub report_summary {
    my $report;
    my $arg;
    my $point_value;
    my $sum = 0;
    cmt("######################################################\n");
    cmt("Summary for $uname:\n\n");

    foreach $arg (@test_bases) {
	$point_value = 15*$progress{$arg};  # 15 points for each simulation
	cmt("$arg:\t\t$point_value points\n");
	$sum += $point_value;
    }
    if ($sum > 0) {
	cmt("(10 more points for at least one successful run)\n");
	$sum += 10  # If anything worked, add 10 points for successful run
    }
    cmt("TOTAL POINTS: $sum/100\n");
    cmt("######################################################\n");
}


sub cmt {
    my ($str) = @_;
#  print $str;
    print(COMMENTS $str);
}


sub now {
    my $ret;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    $ret = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat')[$wday];
    $ret .= " ";
    $ret .= ('Jan','Feb','Mar','Apr','May','Jun','Jul',
	     'Aug','Sep','Oct','Nov','Dec')[$mon];
    $ret .= " $mday, ";
    $ret .= $year + 1900;
    $ret .= " at ${hour}:${min}:${sec} ";
    if ( $isdst ) {
	$ret .= "EDT";
    } else {
	$ret .= "EST";
    }
    return $ret;
}
