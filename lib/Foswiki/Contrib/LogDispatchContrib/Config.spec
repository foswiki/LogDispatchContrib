#---+ Logging and Statistics
#---++ LogDispatch configuration
# With LogDispatch, multiple logging methods can be enabled at the same time.
# For similar behavior to the default Foswiki loggers, enable either the FileRolling
# or the File logger,  and also enable the Screen logger.
# <ul><li>The <code>FileRolling</code> logger will write a date-stamped file similar to the old Compatibility logger used on Foswiki 1.0.x</li>
# <li>The <code>File</code> logger writes a simple log file without any stamping or rotating.  File rotation or archiving needs to be done external to Foswiki.</li></ul>
# Only the above File based loggers implement the <code> eachEventSince</code> function for processing log events.
# <ul><li>The <code>Screen</code> logger will write errors and other critical messages to the STDERR file,  which was also done by the default Foswiki loggers</li>
# <li>The <code>Syslog</code> logger uses Sys::Syslog to write to the syslogd socket for local or remote logging.</li></ul>

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the rolling file logger.  This method logs to a simple text file,
# date-stamping each filename per the specified pattern.
$Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = $TRUE;

# **STRING 20** DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{FileRolling}{Enabled}**
# Pattern to use for the filenames.  File names are built from the log class (error, debug, events) and this suffix.
# Date format is specified by <code>%d{..pattern..}%</code>.  Valid pattern characters include <ul><li>y - Year digit</li>
# <li>M - Month digit or name if > 2 characters</li><li>d - day</li><li>w - week number</li></ul>The <code>$</code> will
# insert the process ID, which can be helpful in extremely busy systems, or on systems that do not support file locking (flock).
$Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern} = '-%d{yyyy-MM}.log';

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the plain file logger.  This method logs to a simple text file
# without any locking or file rotation.
$Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} = $FALSE;

# **PERL EXPERT /LogDispatch/i.test({Log}{Implementation})**
# Maps the 8 standard log levels (debug-0 info-1, notice-2, warning-3, error-4, critical-5, alert-6 and emergency-7) to a filename prefix
# used by the File* based loggers.
$Foswiki::cfg{Log}{LogDispatch}{FileMapping} = {
    debug     => 'debug',
    info      => 'events',
    notice    => 'error',
    warning   => 'error',
    error     => 'error',
    critical  => 'error',
    alert     => 'error',
    emergency => 'error',
 };

# **PERL EXPERT /LogDispatch/i.test({Log}{Implementation})**
# Specifies the range of events (0-7) that are logged to a file.
# This hash is the reverse of the FileMapping hash.
$Foswiki::cfg{Log}{LogDispatch}{FileRange} = {
    debug  => 'debug:debug',
    events => 'info:info',
    error  => 'notice:emergency',
 };


# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the "Screen" logger.  This method directs messages to the
# STDERR output.  STDERR is normally recorded in the Apache error log.
# When enabled, error, critical, emergency and alert messages are
# written to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled} = $TRUE;

# **SELECT debug,info,notice,warn,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Screen}{Enabled}**
# Choose the minimum log level logged to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{MinLevel} = 'error';

# **SELECT debug,info,notice,warn,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Screen}{Enabled}**
# Choose the maximum log level logged to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{MaxLevel} = 'emergency';

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the "Syslog" logger.  This method uses the system syslog utility
# to log messages to the system log.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Enabled} = $FALSE;

# **SELECT auth,authpriv,cron,daemon,kern,local0,local1,local2,local3,local4,local5,local6,local7,mail,news,syslog,user,uucp DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Choose the facility used by the Syslog logger
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Facility} = 'user';

# **STRING 20 DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Choose an identifier to prepend to each log record
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Identifier} = 'Foswiki';

# **SELECT debug,info,notice,warn,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Choose the minimum log level logged to syslog.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{MinLevel} = 'warn';

# **SELECT debug,info,notice,warn,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Choose the maximum log level logged to syslog.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{MaxLevel} = 'emergency';

# **BOOLGROUP EXPERT ndelay,noeol,nofatal,nonul,nowait,perror,pid DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Specify log options to Sys::Syslog.  See the documentation for openlog and
# http://perldoc.perl.org/Sys/Syslog.html for details.  Recommended options are:
# <code>nofatal</code> - Logger should not die if syslog is unavailable,  and <code>pid</code> - Include the process ID in the log message.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Logopt} = 'nofatal,pid';

