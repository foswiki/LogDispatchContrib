#---+ Logging and Statistics

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the plain file logger.  This method logs to a simple text file 
# without any locking or file rotation.
$Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} = $FALSE;

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the "Screen" logger.  This method directs messages to the 
# STDERR output.  STDERR is normally recorded in the Apache error log.
# When enabled, error, critical, emergency and alert messages are
# written to STDERR.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled} = $TRUE;

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the "Syslog" logger.  This method uses the system syslog utility
# to log messages to the system log.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Enabled} = $FALSE;

