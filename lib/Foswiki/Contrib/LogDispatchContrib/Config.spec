#---+ Logging and Statistics

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the plain file logger.  This method logs to a simple text file 
# without any locking or file rotation.
$Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} = $FALSE;

# **STRING 40 DISPLAY_IF {Log}{LogDispatch}{File}{Enabled}**
$Foswiki::cfg{Log}{LogDispatch}{File}{eventsFilename} = 'events.log';

# **STRING 40 DISPLAY_IF {Log}{LogDispatch}{File}{Enabled}**
$Foswiki::cfg{Log}{LogDispatch}{File}{errorsFilename} = 'error.log';

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the "Screen" logger.  This method directs all messages to the 
# STDERR output.  STDERR is normally recorded in the Apache error log.
$Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled} = $FALSE;

# **BOOLEAN DISPLAY_IF /LogDispatch/i.test({Log}{Implementation})**
# Enable the "Syslog" logger.  This method uses the system syslog utility
# to log messages to the system log.
$Foswiki::cfg{Log}{LogDispatch}{Syslog}{Enabled} = $FALSE;

# **BOOLGROUP info,warning,error,critical,alert,emergency,debug**
$Foswiki::cfg{Log}{LogDispatch}{File}{levels} = '';

