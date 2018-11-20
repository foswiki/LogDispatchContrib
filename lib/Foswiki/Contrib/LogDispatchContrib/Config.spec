#---+ Logging and Statistics
#---++ LogDispatchContrib
# With LogDispatch, multiple logging methods can be enabled at the same time.
# For similar behavior to the default Foswiki loggers, enable either the FileRotate
# or the File logger, and also enable the Screen logger.
# <ul><li>The <code>FileRotate</code> logger will rotate files on recurring dates </li>
# <li>The <code>File</code> logger writes a simple log file without any stamping or rotating.  File rotation or archiving needs to be done external to Foswiki.</li></ul>
# Only the above File based loggers implement the <code> eachEventSince</code> function for processing log events.
# <ul><li>The <code>Screen</code> logger will write errors and other critical messages to the STDERR file,  which was also done by the default Foswiki loggers</li>
# <li>The <code>Syslog</code> logger uses Sys::Syslog to write to the syslogd socket for local or remote logging.</li></ul>

# **SELECT none,hash,x.x.x.x**
# Hide IP Addresses logged in the event log.  Default: IP addresses are logged.<ul>
# <li><code>x.x.x.x</code> will log that in the field, meaning that multiple requests from the same IP address cannot be correlated.</li>
# <li><code>hash</code> will encode the ip addresses, so they can be correlated, but not identified.</li></ul>
# Note: the hash method does not work for IPv6 addresses.
$Foswiki::cfg{Log}{LogDispatch}{MaskIP} = 'none';

# **PERL EXPERT**
# Defines which logger should be iterated over using <code>Func::eachEventSince()</code>.  If multiple loggers are active for the same logging level,
# the first listed logger will be used.  If no loger is active for a level, an empty iterator is returned.
# A logging level should only be included once in the list.  In the case of the <code>File</code> and
# <code>FileRotate</code> loggers, the filename is determined by mapping the level to the file prefix using the <code>{Log}{LogDispatch}{FileRange}</code> setting.
# By default, foswiki iterates only the "info" logging level, for statistics processing.
#
# The <code>Screen</code> and <code>Syslog</code>  loggers do not support event iteration.
$Foswiki::cfg{Log}{LogDispatch}{EventIterator} = {
    'debug' => 'FileRotate,File',
    'info' => 'FileRotate,File',
    'notice' => 'FileRotate,File',
    'warning' => 'FileRotate,File',
    'error' => 'FileRotate,File',
    'critical' => 'FileRotate,File',
    'alert' => 'FileRotate,File',
    'emergency' => 'FileRotate,File',
};

# **BOOLEAN**
# Enable the rolling file logger.  This method logs to a simple text file,
# date-stamping each filename per the specified pattern.
$Foswiki::cfg{Log}{LogDispatch}{FileRotate}{Enabled} = $TRUE;

# **PERL EXPERT DISPLAY_IF="{Log}{LogDispatch}{FileRotate}{Enabled}"**
# Specifies the range of levels <em>by name</em> that are logged to each file. Entered in format of:<br />
# <code>filename-prefix => 'minimum:maximum',</code> (be sure to include comma!)<br />
# The ranges may overlap or skip levels<br />
# <code>(debug-0 info-1, notice-2, warning-3, error-4, critical-5, alert-6 and emergency-7)</code></br />
# Ex. <code>notice:warning</code> would be valid,  but <code>warning:notice</code> is invalid.
# Additional files can be added following the same format.  However, by default Foswik only logs to debug, info, warning and error levels.
$Foswiki::cfg{Log}{LogDispatch}{FileRotate}{FileLevels} = {
    debug  => 'debug:debug',
    events => 'info:info',
    configure => 'notice:notice',
    error  => 'warning:emergency',
};

# **SELECT yearly,monthly,weekly,daily,hourly DISPLAY_IF="{Log}{LogDispatch}{FileRotate}{Enabled}"**
# Recurrence of files being rotated.  
$Foswiki::cfg{Log}{LogDispatch}{FileRotate}{Recurrence} = 'monthly';

# **NUMBER 10 DISPLAY_IF="{Log}{LogDispatch}{FileRotate}{Enabled}"** 
# Number of files to keep. Note that based on the recurrence you've chosen you might change this to a different value. 
$Foswiki::cfg{Log}{LogDispatch}{FileRotate}{MaxFiles} = 12;

# **PERL EXPERT DISPLAY_IF="{Log}{LogDispatch}{FileRotate}{Enabled}"**
# Array of fields to be joined together to build the log record.  The default value will generate log records compatible with the default Foswiki loggers
# Each entry consists of a list,  first the delimiter used to build the records, and then each logger field to be included.
# if an entry for the log level being written is not found, then the <code>DEFAULT</code> layout will be used.
# Arrays can be nested no more than one level deep.   Valid fields are:
# timestamp, level, user, action, webTopic, extra, agent, remoteAddr, and caller.
$Foswiki::cfg{Log}{LogDispatch}{FileRotate}{Layout} =  {
        info => [' | ', [' ', 'timestamp', 'level'], 'user', 'action', 'webTopic', [' ', 'extra', 'agent', '*', ], 'remoteAddr'],
        notice => [' | ', [' ', 'timestamp', 'level'], 'user', 'remoteAddr', 'setting', 'oldvalue', 'newvalue'],
        DEFAULT => [' | ', [' ', 'timestamp', 'level'], [' ', 'caller', 'extra'] ],
        };

# **BOOLEAN**
# Enable the plain file logger.  This method logs to a simple text file
# without any locking or file rotation.
$Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} = $FALSE;

# **PERL EXPERT DISPLAY_IF="{Log}{LogDispatch}{File}{Enabled}"**
# Specifies the range of levels <em>by name</em> that are logged to each file. Entered in format of:<br />
# <code>filename-prefix => 'minimum:maximum',</code> (be sure to include the trailing comma!)<br />
# The ranges may overlap or skip levels, but must be in order of lower:higher.<br />
# <code>(debug-0 info-1, notice-2, warning-3, error-4, critical-5, alert-6 and emergency-7)</code><br />
# Ex. <code>notice:warning</code> would be valid,  but <code>warning:notice</code> is invalid.
# Additional files can be added following the same format.  By default, Foswik only logs to debug, info, warning and error levels.<br /><br/>
# An optional 3rd parameter may be specified <code>minimum:maximum:filter</code>.  If a simple matching string or regular expression is provided, the log messages to the named file will be 
# further filtered by the pattern match and only logged when the pattern matches.  The pattern is tested against the completely assembled log record.  For example to send all authentication failures to a unique log file
# Add a line:   <code>authfail => 'info:info:AUTHENTICATION FAILURE',</code>   For case-insensitive matches, prefix the string with <code>(?i)</code>, for example: <code>... => 'info:info:(?i)authentication'</code> Note: Filtered files will not be considered for <code>eachEventSince</code> processing.
$Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels} = {
    debug  => 'debug:debug',
    events => 'info:info',
    configure => 'notice:notice',
    error  => 'warning:emergency',
};

# **PERL EXPERT DISPLAY_IF="{Log}{LogDispatch}{File}{Enabled}"**
# Array of fields to be joined together to build the log record.  The default value will generate log records compatible with the default Foswiki loggers
# Each entry consists of a list,  first the delimiter used to build the records, and then each logger field to be included.
# if an entry for the log level being written is not found, then the <code>DEFAULT</code> layout will be used.
# Arrays can be nested no more than one level deep.   Valid fields are:
# timestamp, level, user, action, webTopic, extra, agent, remoteAddr, and caller.
$Foswiki::cfg{Log}{LogDispatch}{File}{Layout} =  {
        info => [' | ', [' ', 'timestamp', 'level'], 'user', 'action', 'webTopic', [' ', 'extra', 'agent', '*', ], 'remoteAddr'],
        notice => [' | ', [' ', 'timestamp', 'level'], 'user', 'remoteAddr', 'setting', 'oldvalue', 'newvalue'],
        DEFAULT => [' | ', [' ', 'timestamp', 'level'], [' ', 'caller', 'extra'] ],
        };

# **BOOLEAN**
# Enable the "Screen" logger.  This method directs messages to the
# STDERR output.  STDERR is normally recorded in the Apache error log.
# When enabled, error, critical, emergency and alert messages are
# written to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled} = $TRUE;

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF="{Log}{LogDispatch}{Screen}{Enabled}"**
# Choose the minimum log level logged to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{MinLevel} = 'error';

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF="{Log}{LogDispatch}{Screen}{Enabled}"**
# Choose the maximum log level logged to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{MaxLevel} = 'emergency';

# **PERL EXPERT DISPLAY_IF="{Log}{LogDispatch}{Screen}{Enabled}"**
# Array of fields to be joined together to build the log record.  The default value will generate log records compatible with the default Foswiki loggers
# Each entry consists of a list,  first the delimiter used to build the records, and then each logger field to be included.
# if an entry for the log level being written is not found, then the <code>DEFAULT</code> layout will be used.
# Arrays can be nested no more than one level deep.   Valid fields are:
# timestamp, level, user, action, webTopic, extra, agent, remoteAddr, and caller.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{Layout} =  {
        info => [' | ', [' ', 'timestamp', 'level'], 'user', 'action', 'webTopic', [' ', 'extra', 'agent', '*',], 'remoteAddr'],
        notice => [' | ', [' ', 'timestamp', 'level'], 'user', 'remoteAddr', 'setting', 'oldvalue', 'newvalue'],
        DEFAULT => [' | ', [' ', 'timestamp', 'level'], [' ', 'caller', 'extra'] ],
        };

# **BOOLEAN**
# Enable the "Syslog" logger.  This method uses the system syslog utility
# to log messages to the system log.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Enabled} = $FALSE;

# **SELECT auth,authpriv,cron,daemon,kern,local0,local1,local2,local3,local4,local5,local6,local7,mail,news,syslog,user,uucp DISPLAY_IF="{Log}{LogDispatch}{Syslog}{Enabled}"**
# Choose the facility used by the Syslog logger
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Facility} = 'user';

# **STRING 20 DISPLAY_IF="{Log}{LogDispatch}{Syslog}{Enabled}"**
# Choose an identifier to prepend to each log record
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Identifier} = 'Foswiki';

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF="{Log}{LogDispatch}{Syslog}{Enabled}"**
# Choose the minimum log level logged to syslog.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{MinLevel} = 'notice';

# **SELECT debug,info,notice,warning,error,critical,alert,emergency DISPLAY_IF="{Log}{LogDispatch}{Syslog}{Enabled}"**
# Choose the maximum log level logged to syslog.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{MaxLevel} = 'emergency';

# **PERL EXPERT DISPLAY_IF="{Log}{LogDispatch}{Syslog}{Enabled}"**
# Array of fields to be joined together to build the log record.  The default value will generate log records compatible with the default Foswiki loggers
# Each entry consists of a list,  first the delimiter used to build the records, and then each logger field to be included.
# if an entry for the log level being written is not found, then the <code>DEFAULT</code> layout will be used.
# Arrays can be nested no more than one level deep.   Valid fields are:
# timestamp, level, user, action, webTopic, extra, agent, remoteAddr, and caller.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Layout} =  {
        info => [' | ', [' ', 'timestamp', 'level'], 'user', 'action', 'webTopic', [' ', 'extra', 'agent', '*', ], 'remoteAddr'],
        notice => [' | ', [' ', 'timestamp', 'level'], 'user', 'remoteAddr', 'setting', 'oldvalue', 'newvalue'],
        DEFAULT => [' | ', [' ', 'timestamp', 'level'], [' ', 'caller', 'extra'] ],
        };

# **BOOLGROUP ndelay,noeol,nofatal,nonul,nowait,perror,pid EXPERT DISPLAY_IF="{Log}{LogDispatch}{Syslog}{Enabled}"**
# Specify log options to Sys::Syslog.  See the documentation for openlog and
# http://perldoc.perl.org/Sys/Syslog.html for details.  Recommended options are:
# <code>nofatal</code> - Logger should not die if syslog is unavailable,  and <code>pid</code> - Include the process ID in the log message.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Logopt} = 'nofatal,pid';
1;
