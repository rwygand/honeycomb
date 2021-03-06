#!/usr/bin/ksh
#
# $Id: pagein.sh 10845 2007-05-19 02:31:46Z bberndt $
#
# Copyright � 2008, Sun Microsystems, Inc.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   # Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
#   # Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
#   # Neither the name of Sun Microsystems, Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



# 
# pagein.sh - pages paged in by process name.
# 
# USAGE:        pagein.sh [-n name] [-p pid] [-t top] [interval [count]]
# 
#               pagein.sh              # default output, 5 second samples
#
#               -n name         # this process name only
#               -p PID          # this PID only
#               -t top          # print top number only
#       eg,
#               pagein.sh 1            # 1 second samples
#               pagein.sh -t 10        # print top 10 only
#               pagein.sh -n bash      # monitor processes named "bash"
#               pagein.sh 5 12         # print 12 x 5 second samples
##

##############################
# --- Process Arguments ---
#

### default variables
opt_name=0; opt_pid=0; filter=0; pname=.; pid=0; interval=5; count=-1;
opt_top=0; top=0

### process options
while getopts hn:p:t: name
do
        case $name in
        n)      opt_name=1; pname=$OPTARG ;;
        p)      opt_pid=1; pid=$OPTARG ;;
        t)      opt_top=1; top=$OPTARG ;;
	h|?)    cat <<-END >&2
                USAGE: pagein.sh [-n name] [-p pid] [-t top] [interval [count]]
         
                       -n name         # this process name only
                       -p PID          # this PID only
                       -t top          # print top number only
               eg,
                       pagein.sh              # default output, 5 second samples
                       pagein.sh 1            # 1 second samples
                       pagein.sh -t 10        # print top 10 only
                       pagein.sh -n bash      # monitor processes named "bash"
                       pagein.sh 5 12         # print 12 x 5 second samples
		END
                exit 1
        esac
done

shift $(( $OPTIND - 1 ))

### option logic
if [[ "$1" > 0 ]]; then
        interval=$1; shift
fi
if [[ "$1" > 0 ]]; then
        count=$1; shift
fi
if (( opt_name || opt_pid )); then
        filter=1
fi

#################################
# --- Main Program, DTrace ---
#
/usr/sbin/dtrace -n '
#pragma D option quiet
 
/*
  * Command line arguments
  */
 inline int OPT_name    = '$opt_name';
 inline int OPT_pid     = '$opt_pid';
 inline int OPT_top     = '$opt_top';
 inline int INTERVAL    = '$interval';
 inline int COUNTER     = '$count';
 inline int FILTER      = '$filter';
 inline int TOP         = '$top';
 inline int PID         = '$pid';
 inline string NAME     = "'$pname'";
 
/* print header */
dtrace:::BEGIN
{
        counts = COUNTER;
        secs = INTERVAL;
        printf("Tracing... Please wait.\n");
}

vminfo:::pgpgin
/pid != $pid/
{ 
       /* default is to trace unless filtering, */
       this->ok = FILTER ? 0 : 1;

       /* check each filter, */
       (OPT_name == 1 && NAME == execname)? this->ok = 1 : 1;
       (OPT_pid == 1 && PID == pid) ? this->ok = 1 : 1;
}

vminfo:::pgpgin
/this->ok/
{
        @pg[pid, execname] = sum(arg0);

        this->ok = 0;
}

/*
 * Timer
 */
profile:::tick-1sec
{
       secs--;
}

/*
 * Print Report
 */
profile:::tick-1sec
/secs == 0/
{
        /* fetch 1 min load average */
        this->load1a  = `hp_avenrun[0] / 65536;
        this->load1b  = ((`hp_avenrun[0] % 65536) * 100) / 65536;

        printf("\n%Y,  load: %d.%02d\n\n", walltimestamp, this->load1a,
               this->load1b);

        printf("%6s %-16s %s\n", "PID", "CMD", "NUM_PAGES_IN");
        printa("%6d %-16s %@d\n", @pg);

        /* clear data */
        trunc(@pg);
        secs = INTERVAL;
        counts--;
}

/*
 * End of program
 */
profile:::tick-1sec
/counts == 0/
{
       exit(0);
}

/*
 * Cleanup for Ctrl-C
 */
dtrace:::END
{
       trunc(@pg);
}
'