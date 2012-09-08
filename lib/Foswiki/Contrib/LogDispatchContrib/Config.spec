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

# **SELECT none,hash,x.x.x.x DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Hide IP Addresses logged in the event log.  Default: IP addresses are logged.<ul>
# <li><code>x.x.x.x</code> will log that in the field, meaning that multiple requests from the same IP address cannot be correlated.</li>
# <li><code>hash</code> will encode the ip addresses, so they can be correlated, but not identified.</li></ul>
# Note: the hash method does not work for IPv6 addresses.
$Foswiki::cfg{Log}{LogDispatch}{MaskIP} = 'none';

# **PERL EXPERT /LogDispatch/i.test({Log}{Implementation})**
# Defines which logger should be iterated over using <code>Func::eachEventSince()</code>.  If multiple loggers are active for the same logging level,
# the first listed logger will be used.  If no loger is active for a level, an empty iterator is returned.
# A logging level should only be included once in the list.  In the case of the <code>File</code> and
# <code>FileRolling</code> loggers, the filename is determined by mapping the level to the file prefix using the <code>{Log}{LogDispatch}{FileRange}</code> setting.
# By default, foswiki iterates only the "info" logging level, for statistics processing.
#
# The <code>Screen</code> and <code>Syslog</code>  loggers do not support event iteration.
$Foswiki::cfg{Log}{LogDispatch}{EventIterator} = {
    'debug' => 'FileRolling,File',
    'info' => 'FileRolling,File',
    'notice' => 'FileRolling,File',
    'warning' => 'FileRolling,File',
    'error' => 'FileRolling,File',
    'critical' => 'FileRolling,File',
    'alert' => 'FileRolling,File',
    'emergency' => 'FileRolling,File',
};

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the rolling file logger.  This method logs to a simple text file,
# date-stamping each filename per the specified pattern.
$Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = $TRUE;

# **PERL EXPERT /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{FileRolling}{Enabled}**
# Specifies the range of levels <em>by name</em> that are logged to each file. Entered in format of:<br />
# <code>filename-prefix => 'minimum:maximum',</code> (be sure to include comma!)<br />
# The ranges may overlap or skip levels<br />
# <code>(debug-0 info-1, notice-2, warning-3, error-4, critical-5, alert-6 and emergency-7)</code></br />
# Ex. <code>notice:warning</code> would be valid,  but <code>warning:notice</code> is invalid.
# Additional files can be added following the same format.  However, by default Foswik only logs to debug, info, warning and error levels.
$Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} = {
    debug  => 'debug:debug',
    events => 'info:info',
    error  => 'notice:emergency',
};

# **STRING 20** DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{FileRolling}{Enabled}**
# Pattern to use for the filenames.  File names are built from the log class (error, debug, events) and this suffix.
# Date format is specified by <code>%d{..pattern..}%</code>.  Valid pattern characters include <ul><li>y - Year digit</li>
# <li><code>M</code> - Month digit or name if > 2 characters</li><li><code>d</code> - day</li><li><code>$</code> - Process ID</li></ul>The
# process ID can be helpful to avoid log file contention in extremely busy systems, or on systems that do not support file locking (flock),
# but is incompatible with the <code>eachEventSince</code> log processor..
$Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern} = '-%d{yyyy-MM}.log';

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the plain file logger.  This method logs to a simple text file
# without any locking or file rotation.
$Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} = $FALSE;

# **PERL EXPERT /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{File}{Enabled}**
# Specifies the range of levels <em>by name</em> that are logged to each file. Entered in format of:<br />
# <code>filename-prefix => 'minimum:maximum',</code> (be sure to include the trailing comma!)<br />
# The ranges may overlap or skip levels, but must be in order of lower:higher.<br />
# <code>(debug-0 info-1, notice-2, warning-3, error-4, critical-5, alert-6 and emergency-7)</code><br />
# Ex. <code>notice:warning</code> would be valid,  but <code>warning:notice</code> is invalid.
# Additional files can be added following the same format.  By default, Foswik only logs to debug, info, warning and error levels.<br /><br/>
# An optional 3rd parameter may be specified <code>minimum:maximum:filter</code>.  If a simple matching string or regular expression is provided, the log messages to the named file will be 
# further filtered by the pattern match and only logged when the pattern matches.   For example to send all authentication failures to a unique log file
# Add a line:   <code>authfail => 'info:info:AUTHENTICATION FAILURE',</code>   Note: Filtered files will not be considered for <codeLeachEventSince</code> processing.
$Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels} = {
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

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Screen}{Enabled}**
# Choose the minimum log level logged to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{MinLevel} = 'error';

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Screen}{Enabled}**
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

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Choose the minimum log level logged to syslog.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{MinLevel} = 'warning';

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Choose the maximum log level logged to syslog.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{MaxLevel} = 'emergency';

# **BOOLGROUP EXPERT ndelay,noeol,nofatal,nonul,nowait,perror,pid DISPLAY_IF /LogDispatch/i.test({Log}{Implementation}) && {Log}{LogDispatch}{Syslog}{Enabled}**
# Specify log options to Sys::Syslog.  See the documentation for openlog and
# http://perldoc.perl.org/Sys/Syslog.html for details.  Recommended options are:
# <code>nofatal</code> - Logger should not die if syslog is unavailable,  and <code>pid</code> - Include the process ID in the log message.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Logopt} = 'nofatal,pid';

